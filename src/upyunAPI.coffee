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
toArray                 = require 'stream-to-array'

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

# For upyun, there are limitations for API calls on the same bucket.
# The minumun interval between two operations as following:
# delete 143ms
# get   100ms
# head  150ms
# put   500ms
# post  500ms
# That may be changed in future

WAIT_FOR_GET = 120
WAIT_FOR_PUT = 600
WAIT_FOR_DEL = 160

delayCall = (fn, delay, cb) ->
    fn (err, res, body) ->
        if err?
            cb err
        else if res.statusCode is 429
            setTimeout ->
                delayCall fn, delay, cb
            , delay
        else
            cb err, res, body

httpGet = (params, cb) ->
    delayCall request.bind(@, params), WAIT_FOR_GET, cb

httpPut = (params, cb) ->
    delayCall request.put.bind(request, params), WAIT_FOR_PUT, cb

httpDel = (params, cb) ->
    delayCall request.del.bind(request, params), WAIT_FOR_DEL, cb

getHttpStream = (params, cb) ->
    request params
    .on 'response', (res) ->
        if res.statusCode is 429
            setTimeout ->
                getHttpStream params, cb
            , WAIT_FOR_GET
        else
            cb null, @

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

    getOneFolderInfo = (folder, cb) ->

        getPagedResult = (cb) ->

            oneRequest = (iter, initial, cb) ->
                params = getHttpParams host, folder, opts
                params.headers['x-list-iter'] = iter if iter?

                httpGet params, (err, res, body) ->
                    return cb err if err?

                    if res.statusCode isnt 200
                        if Buffer.isBuffer body
                            bpdy = body.toString()
                        return cb { statusCode: res.statusCode, body: body, filename: folder }

                    iter = res.headers['x-upyun-list-iter']
                    # the latest update of upyun use this mgix number as a sign for NO-MORE files
                    hasMore = iter? and (iter != 'g2gCZAAEbmV4dGQAA2VvZg') and iter.toLowerCase() isnt 'none'

                    if body[body.length-1] isnt '\n'
                        body += '\n'

                    initial += body

                    if hasMore
                        oneRequest iter, initial, cb
                    else
                        cb null, initial

            oneRequest null, '', cb

        getPagedResult (err, upYunResult) ->
            return cb() if not upYunResult

            files = upYunResult.split '\n'
            async.eachLimit files, 8
            , (f, cb) ->
                return cb() if not f.trim()

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
                                httpGet p, (err, res, body) ->
                                    return cb err if err?
                                    if res.statusCode isnt 200
                                        if Buffer.isBuffer body
                                            body = body.toString()
                                        return cb {
                                            statusCode: res.statusCode
                                            body: body
                                            filename: filePath
                                        }
                                    vf.contents = body
                                    emitter.emit 'data', vf
                                    cb()
                            else
                                getHttpStream p, (err, res) ->
                                    if err?
                                        cb err
                                    else
                                        vf.contents = res.pipe(through())
                                        emitter.emit 'data', vf
                                        cb()
                        else
                            emitter.emit 'data', vf

                            cb()
                    else
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
    toArray stream, (err, arr) ->
        return cb err if err?
        cb null, Buffer.concat arr

api.putFile = (startingFolder, file, opts, cb) ->
    return cb() if file.isNull()

    uploadToServer = (length, data, cb)->
        host = opts.host ? DEFAULT_HOST
        folder = path.join '/', startingFolder, file.relative
        params = getHttpParams host, folder, opts, length, 'PUT'
        params.body = data if data.length > 0
        params.headers.mkdir = opts.mkdir ? true
        params.headers['content-length'] = length
        params.headers['content-type'] = opts['content-type'] if opts['content-type']?
        params.headers['content-md5'] = md5 data if opts.md5
        httpPut params, (err, res, body) ->
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

    httpDel params, (err, res, body) ->
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
        httpGet params, (err, res, body) ->
            return cb err if err?
            return cb() if res.statusCode is 404

            if res.statusCode isnt 200
                return cb { statusCode: res.statusCode, body: body, filename: folder }

            if not body
                return api.delFileOrDir folder, opts, cb

            files = body.split '\n'
            async.eachLimit files, 8
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