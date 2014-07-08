gulp-upyun
==============

3 gulp plugins for [UPYun service](https://www.upyun.com/index.html).

Install via [npm](https://npmjs.org/package/gulp-upyun):

```
npm install gulp-upyun --save-dev
```

## Example ##

### Download ###

``` js
var gulp = require('gulp')
var upyunSrc = require('gulp-upyun').upyunSrc

var options = {
    username: 'username',
    passeord: 'password'
}

gulp.task('default', function() {
    upyunSrc('/yourbucket/dist/**/*', ['!/yourbucket/dist/**/*.png'], options)
        .pipe(gulp.dest('./out'))
})
```

Options we supported:

* username: your username access to yoyun bucket
* username: password of your username
* read: default: true. Setting this to false will return file.contents as null and not read the file at all.
* buffer: default: true. Setting this to false will return file.contents as a stream and not buffer files.

Negative globs could be omited.

``` js
gulp.task('default', function() {
    upyunSrc('/yourbucket/**/*', options
        .pipe(gulp.dest('./out'))
})
```

### Upload ###

``` js
var gulp = require('gulp')
var upyunDest = require('gulp-upyun').upyunDest

var options = {
    username: 'username',
    password: 'password'
}

var folderOnUpyun = '/yourbucket/dist'

gulp.task('default', function() {
    gulp.src('images/**/*')
      .pipe(upyunDest(folderOnUpyun, options))
})
```

Options we supported:

* md5: default: true. Verify the checksum of file on upyun.

### Delete folder or file on upyun ###

``` js
var upyunRimraf = require('gulp-upyun').upyunRimraf

var options = {
    username: 'username',
    password: 'password'
}

// delete a folder
upyunRimraf('/bucket/dist/', options, function(err) {
    ...
})

// delete a file
upyunRimraf('/bucket/dist/rgb.jpg', options, function(err) {
})
```

`upyunRimraf` will delete the folder recursively.

### upyunRimraf could be a writable stream ###

``` js
var gulp = require('gulp')
var upyunSrc = require('gulp-upyun').upyunSrc
var upyunRimraf = require('gulp-upyun').upyunRimraf

var options = {
    username: 'username',
    password: 'password'
}

gulp.task('default', function() {
    upyunSrc('/yourbucket/dist/**/*', options)
        .pipe(upyunRimraf(options))
})
```

### Build ##

Default `gulp` task will compile all of CoffeeScript codes in `./src` to JS in `./lib`.

### Test ##

Before you run `npm test`, you have to put your `credential.js` into `./test`.

``` js
module.exports = {
    username: 'username',
    password: 'password'
}
```

Then run `npm test`.