{ PluginError, log } = require 'gulp-util'
es                   = require 'event-stream'
api                  = require './upyunAPI'

module.exports = (ourGlob, negatives, opts) ->
    if not Array.isArray negatives
        opts = negatives ? {}
        negatives = []
    else
        negatives ?= []
        opts ?= {}

    if not opts.username?
        throw new PluginError 'gulp-upyun-src', 'username required'

    if not opts.password?
        throw new PluginError 'gulp-upyun-src', 'password required'

    es.readable (count, cb) ->
        stream = @
        api.getAllMatchedFiles ourGlob, negatives, opts, (err, vfs) ->
            if err?
                if typeof(err) is 'object' and err.statusCode is 404
                    stream.emit 'end'
                    return cb()
                else
                    return cb err

            vfs.forEach (vf) -> stream.emit 'data', vf

            stream.emit 'end'
            cb()
