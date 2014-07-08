{ PluginError, log } = require 'gulp-util'
api                  = require './upyunAPI'
through              = require 'through2'
path                 = require 'path'

PLUGIN_NAME = 'gulp-upyun-rimfaf'

module.exports = (filePath, opts, cb) ->
    if typeof filePath is 'string'
        deleteDirectly = true
        filePath = if filePath[0] isnt '/' then '/' + filePath else filePath
        if typeof opts is 'function'
            opts = {}
            cb = opts
        else
            opts ?= {}
            cb ?= ->
    else
        deleteDirectly = false
        opts = filePath ? {}

    if not opts.username?
        throw new PluginError PLUGIN_NAME, 'username required'

    if not opts.password?
        throw new PluginError PLUGIN_NAME, 'password required'

    finish = (filepath, err, cb) ->
        if err?
            log "#{PLUGIN_NAME}: delete #{filepath} errors(#{err})" if opts.verbose
            cb err
        else
            log "#{PLUGIN_NAME}: deleted #{filepath}" if opts.verbose
            cb()

    if deleteDirectly
        if filePath.slice(-1) is '/'
            api.delFolder filePath, opts, (err) ->
                finish filePath, err, cb
        else
            api.delFileOrDir filePath, opts, (err) ->
                finish filePath, err, cb
    else
        through.obj (file, enc, cb) ->
            if file.stat.isFile()
                api.delFileOrDir file.path, opts, (err) ->
                    finish file.relative, err, cb
            else
                api.delFolder file.path, opts, (err) ->
                    finish file.relative, err, cb