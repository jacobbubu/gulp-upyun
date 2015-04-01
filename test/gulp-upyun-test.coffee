describe 'gulp-upyun: ', ->
    credential          = require('./common').credential
    should              = require 'should'
    gulp                = require 'gulp'
    upyunSrc            = require '../lib/upyunSrc'
    upyunDest           = require '../lib/upyunDest'
    upyunRimraf         = require '../lib/upyunRimraf'
    { streamToBuffer }  = require '../lib/upyunAPI'
    path                = require 'path'

    testFiles = {}
    testFilesGlob = 'test/testFiles/**/*'
    serverTestFolder = '/ndtest-pic/gulp-dest-test'

    bufferEqual = (a, b) ->
        return undefined if not (Buffer.isBuffer(a) and Buffer.isBuffer(b))
        return false if a.length isnt b.length

        for i in [0...a.length]
            return false if a[i] isnt b[i]
        true

    it 'load test files into an array for later comparison', (done) ->
        gulp.src testFilesGlob
        .on 'data', (file) ->
            testFiles[file.relative] = file
        .once 'err', (err) ->
            throw err
        .once 'end', ->
            done()

    it 'upload test files to upyun should succeed', (done) ->
        opts = credential
        opts.md5 = true
        gulp.src testFilesGlob
        .pipe upyunDest serverTestFolder, opts
        .once 'error', (err) ->
            throw err
        .once 'finish', ->
            done()

    it 'get all files from upyun should succeed', (done) ->
        opts = credential
        upyunSrc "#{serverTestFolder}/**/*", opts
        .once 'end', ->
            done()
        .once 'error', (err) ->
            throw JSON.stringify err
        .on 'data', (file) ->
            if file.stat.isFile()
                bufferEqual(file.contents, testFiles[file.relative].contents).should.be.true
            else
                should.exist testFiles[file.relative]
                testFiles[file.relative].isDirectory().should.be.true

    it 'get all files as a stream should succeed', (done) ->
        pending = 0
        opts = credential
        opts.buffer = false

        result = {}

        upyunSrc "#{serverTestFolder}/**/*", opts
        .once 'end', ->
            recheck = ->
                setTimeout ->
                    return recheck() if pending isnt 0
                    for k, f of testFiles
                        if f.stat.isFile()
                            should.exist result[k]
                            bufferEqual(result[k], f.contents).should.be.true
                    done()
                , 50
            recheck()
        .once 'error', (err) ->
            throw JSON.stringify err
        .on 'data', (file) ->
            if file.stat.isFile()
                pending++
                streamToBuffer file.contents, (err, buffer) ->
                    throw err if err?
                    pending--
                    result[file.relative] = buffer

    it 'should return all jpeg files', (done) ->
        opts = credential
        opts.read = false
        allJpegFiles = (f.relative for k, f of testFiles when path.extname(k) is '.jpg')
        result = []

        upyunSrc "#{serverTestFolder}/**/*.jpg", [], opts
        .once 'end', ->
            allJpegFiles.forEach (filename) ->
                (filename in result).should.be.true
            done()
        .once 'error', (err) ->
            throw JSON.stringify err
        .on 'data', (file) ->
            result.push file.relative

    it 'should return all non-png files', (done) ->
        opts = credential
        opts.read = false
        allNonPngFiles = (f.relative for k, f of testFiles \
            when path.extname(k).length > 0 and path.extname(k) isnt '.png')
        result = []

        upyunSrc "#{serverTestFolder}/**/*", ["!#{serverTestFolder}/**/*.png"], opts
        .once 'end', ->
            allNonPngFiles.forEach (filename) ->
                (filename in result).should.be.true
            done()
        .once 'error', (err) ->
            throw JSON.stringify err
        .on 'data', (file) ->
            result.push file.relative if file.stat.isFile()

    it 'delete all files then check the upyun for verification', (done) ->
        opts = credential
        opts.read= false
        try
            upyunSrc "#{serverTestFolder}/**/*", [], opts
            .pipe upyunRimraf opts
            .once 'finish', ->
                o = credential
                o.read = false
                result = []
                upyunSrc "#{serverTestFolder}/**/*", [], o
                .on 'data', (file) ->
                    result.push file
                .once 'end', ->
                    result.should.be.empty
                    done()
            .once 'error', (err) ->
                throw JSON.stringify err
        catch err
            throw err

    it 'upload again should succeed', (done) ->
        opts = credential
        opts.md5 = true
        gulp.src testFilesGlob
        .pipe upyunDest serverTestFolder, opts
        .once 'error', (err) ->
            throw JSON.stringify err
        .once 'finish', ->
            done()

    it 'delete one single file', (done) ->
        opts = credential
        upyunRimraf path.join(serverTestFolder, 'rgb.jpg'), opts, (err) ->
            should.not.exist err

            opts.read = false
            result = []
            upyunSrc "#{serverTestFolder}/*", opts
            .once 'end', ->
                ('rgb.jpg' in result).should.equal false, "'rgb.jpg' should not exist on upyun"
                done()
            .once 'error', (err) ->
                throw JSON.stringify err
            .on 'data', (file) ->
                result.push path.basename(file.relative) if file.stat.isFile()

    it 'delete whole test folder directly', (done) ->
        opts = credential
        upyunRimraf path.join(serverTestFolder, '/'), opts, (err) ->
            should.not.exist err

            opts.read = false
            upyunSrc "#{serverTestFolder}/**/*", opts
            .once 'error', (err) ->
                done err
            .once 'end', ->
                done()
            .on 'data', (file) ->
                done new Error 'We should not get file in this case'