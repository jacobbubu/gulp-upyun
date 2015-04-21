var PLUGIN_NAME, PluginError, api, log, path, ref, through;

ref = require('gulp-util'), PluginError = ref.PluginError, log = ref.log;

api = require('./upyunAPI');

path = require('path');

through = require('through2-concurrent');

PLUGIN_NAME = 'gulp-upyun-dest';

module.exports = function(startingFolder, opts) {
  var ref1;
  if (opts == null) {
    opts = {};
  }
  if (opts.username == null) {
    throw new PluginError(PLUGIN_NAME, 'username required');
  }
  if (opts.password == null) {
    throw new PluginError(PLUGIN_NAME, 'password required');
  }
  return through.obj({
    maxConcurrency: (ref1 = opts.maxConcurrency) != null ? ref1 : 8
  }, function(file, enc, cb) {
    var self;
    if (file.isNull()) {
      return cb();
    }
    this.emit('upload', {
      file: file,
      status: 'uploading'
    });
    self = this;
    return api.putFile(startingFolder, file, opts, function(err, upyunInfo) {
      if (err != null) {
        if (opts.verbose) {
          log(PLUGIN_NAME + ": upload " + file.relative + " errors(" + err + ")");
        }
        return cb(err);
      }
      if (opts.verbose) {
        log(PLUGIN_NAME + ": uploaded " + file.relative, upyunInfo);
      }
      self.emit('upload', {
        file: file,
        status: 'uploaded'
      });
      return cb();
    });
  }, function(cb) {
    this.emit('allUploaded');
    return cb();
  });
};
