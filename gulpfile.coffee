gulp    = require 'gulp'
rimraf  = require 'gulp-rimraf'
coffee  = require 'gulp-coffee'
gutil   = require 'gulp-util'

gulp.task 'clean',  ->
    gulp.src './lib/**/*', { read: false }
    .pipe rimraf()

gulp.task 'default', ['clean'], ->
    gulp.src './src/*.coffee'
    .pipe coffee( bare: true ).on 'error', gutil.log
    .pipe gulp.dest './lib/'