{ PluginError, log } = require 'gulp-util'
api                  = require './upyunAPI'
path                 = require 'path'
through              = require 'through2-concurrent'

PLUGIN_NAME = 'gulp-upyun-dest'

module.exports = (startingFolder, opts) ->
    opts ?= {}

    if not opts.username?
        throw new PluginError PLUGIN_NAME, 'username required'

    if not opts.password?
        throw new PluginError PLUGIN_NAME, 'password required'

    through.obj { maxConcurrency: opts.maxConcurrency ? 8 }, (file, enc, cb) ->
        return cb() if file.isNull()

        @emit 'upload', { file: file, status: 'uploading'}

        self = @
        api.putFile startingFolder, file, opts, (err, upyunInfo) ->
            if err?
                log "#{PLUGIN_NAME}: upload #{file.relative} errors(#{err})" if opts.verbose
                return cb err

            log "#{PLUGIN_NAME}: uploaded #{file.relative}", upyunInfo if opts.verbose
            self.emit 'upload', { file: file, status: 'uploaded'}
            cb()
    , (cb) ->
        @emit 'allUploaded'
        cb()