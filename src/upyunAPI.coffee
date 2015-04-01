Glob                    = require('glob').Glob
glob2base               = require 'glob2base'
url                     = require 'url'
path                    = require 'path'
async                   = require 'async'
File                    = require 'vinyl'
request                 = require 'request'
Minimatch               = require('minimatch').Minimatch
Stat                    = require('fs').Stats
through                 = require 'through2'
{ sign, md5 }           = require('./upSign')

DEFAULT_HOST = 'http://v0.api.upyun.com'
STAT_TRUE    = -> true
STAT_FALSE   = -> false

getHttpParams = (host, remotePath, opts, contentLength = 0, method = 'GET') ->
    dateHeader = new Date().toUTCString()
    fullUrl = url.resolve host, remotePath
    return {
        url: fullUrl
        headers:
            authorization: "UpYun #{opts.username}:" + sign method, encodeURI(remotePath), opts.password, dateHeader, contentLength
            date: dateHeader
    }

api = {}

api.getAllMatchedFiles = (emitter, ourGlob, negatives, opts, cb) ->
    opts ?= {}
    negatives ?= []

    ourGlob = path.join '/', ourGlob
    globber = new Glob ourGlob
    opts.base = glob2base globber
    opts.read ?= true
    opts.buffer ?= true

    host = opts.host ? DEFAULT_HOST
    startingFolder = opts.base

    # unrelative glob path
    mm = new Minimatch ourGlob
    negativeMms = []
    negativeMms = negatives.map (n) ->
        new Minimatch n

    # result = []

    getOneFolderInfo = (folder, cb) ->
        params = getHttpParams host, folder, opts
        request params, (err, res, body) ->
            return cb err if err?
            if res.statusCode isnt 200
                return cb { statusCode: res.statusCode, body: body, filename: folder }

            return cb() if not body

            files = body.split '\n'
            async.eachLimit files, 8
            , (f, cb) ->
                return cb() if not f

                [name, isFile, length, ctime] = f.split '\t'
                isFile = isFile is 'N'
                filePath = path.join folder, name
                if mm.match(filePath) and (negativeMms.every (nmm) -> nmm.match filePath)
                    stat = new Stat
                    stat.isFile = if isFile then STAT_TRUE else STAT_FALSE
                    stat.isDirectory = if isFile then STAT_FALSE else STAT_TRUE
                    stat.isBlockDevice = STAT_FALSE
                    stat.isCharacterDevice = STAT_FALSE
                    stat.isSymbolicLink = STAT_FALSE
                    stat.isFIFO = STAT_FALSE
                    stat.isSocket = STAT_FALSE
                    stat.ctime = stat.mtime = stat.atime = new Date(ctime * 1000)
                    stat.size = Number length

                    vf = new File
                        cwd: '/'
                        base: startingFolder
                        path: filePath
                        contents: null
                        stat: stat

                    if isFile
                        if opts.read
                            p = getHttpParams host, filePath, opts
                            if opts.buffer
                                p.encoding = null
                                request p, (err, res, body) ->
                                    return cb err if err?
                                    if res.statusCode isnt 200
                                        return cb {
                                            statusCode: res.statusCode
                                            body: body
                                            filename: filePath
                                        }
                                    vf.contents = body
                                    emitter.emit 'data', vf
                                    # result.push vf
                                    cb()
                            else
                                vf.contents = request(p).pipe(through())
                                emitter.emit 'data', vf
                                # result.push vf
                                cb()
                        else
                            emitter.emit 'data', vf
                            # result.push vf
                            cb()
                    else
                        # result.push vf
                        emitter.emit 'data', vf
                        getOneFolderInfo filePath, cb
                else if isFile
                    cb()
                else
                    getOneFolderInfo filePath, cb
            , (err) ->
                cb err

    getOneFolderInfo startingFolder, (err) ->
        if err? then cb err else cb()

streamToBuffer = api.streamToBuffer = (stream, cb)->
    data = new Buffer 0
    stream.on 'data', (chunk) ->
        data = Buffer.concat [chunk]
    .once 'end', ->
        cb null, data
    .once 'error', (err) ->
        cb err

api.putFile = (startingFolder, file, opts, cb) ->
    return cb() if file.isNull()

    uploadToServer = (length, data, cb)->
        host = opts.host ? DEFAULT_HOST
        folder = path.join '/', startingFolder, file.relative
        params = getHttpParams host, folder, opts, length, 'PUT'
        params.body = data
        params.headers.mkdir = opts.mkdir ? true
        params.headers['content-length'] = length
        params.headers['content-type'] = opts['content-type'] if opts['content-type']?
        params.headers['content-md5'] = md5 data if opts.md5
        request.put params, (err, res, body) ->
            return cb err if err?
            if res.statusCode isnt 200
                return cb {
                    statusCode: res.statusCode
                    body: body
                    filename: file.path
                }

            result =
                'x-upyun-width': res.headers['x-upyun-width']
                'x-upyun-height': res.headers['x-upyun-height']
                'x-upyun-frames': res.headers['x-upyun-frames']
                'x-upyun-file-type': res.headers['x-upyun-file-type']

            cb null, result

    if file.isBuffer()
        data = file.contents
        length = data.length
        uploadToServer length, data, (err, res) ->
            return cb err, res
    else if file.isStream()
        streamToBuffer file.contents, (err, data) ->
            return cb err if err?
            uploadToServer data.length, data, (err, res) ->
                return cb err, res
    else
        cb()

api.delFileOrDir = (filePath, opts, cb) ->
    host = opts.host ? DEFAULT_HOST
    params = getHttpParams host, filePath, opts, 0, 'DELETE'

    request.del params, (err, res, body) ->
        return cb err if err?
        switch res.statusCode
            when 200
                cb()
            when 404
                cb()
            else
                cb { statusCode: res.statusCode, body: body, filename: filePath }

api.delFolder = (startingfolder, opts, cb) ->
    host = opts.host ? DEFAULT_HOST

    deleteOneFolder = (folder, cb) ->
        if folder.slice(-1) isnt '/'
            folder = folder + '/'

        params = getHttpParams host, folder, opts
        request params, (err, res, body) ->
            return cb err if err?
            return cb() if res.statusCode is 404

            if res.statusCode isnt 200
                return cb { statusCode: res.statusCode, body: body, filename: folder }

            if not body
                return api.delFileOrDir folder, opts, cb

            files = body.split '\n'
            async.each files
            , (f, cb) ->
                return cb() if not f

                [name, isFile, length, ctime] = f.split '\t'
                isFile = isFile is 'N'
                filePath = path.join folder, name
                if isFile
                    api.delFileOrDir filePath, opts, cb
                else
                    deleteOneFolder filePath, cb
            , (err) ->
                api.delFileOrDir folder, opts, cb

    deleteOneFolder startingfolder, cb

module.exports = api