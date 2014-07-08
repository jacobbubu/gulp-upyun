crypto = require('crypto')

md5 = module.exports.md5 = (value) ->
    checksum = crypto.createHash 'md5'
    checksum.update value ? ''
    checksum.digest 'hex'

module.exports.sign = (method, uri, password, date, contentLength) ->
    contentLength ?= 0
    date ?= new Date().toUTCString()
    md5 [method, uri, date, contentLength, md5(password)].join '&'
