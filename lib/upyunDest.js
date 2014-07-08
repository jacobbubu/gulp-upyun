var PLUGIN_NAME, PluginError, api, log, path, through, _ref;

_ref = require('gulp-util'), PluginError = _ref.PluginError, log = _ref.log;

api = require('./upyunAPI');

through = require('through2');

path = require('path');

PLUGIN_NAME = 'gulp-upyun-dest';

module.exports = function(startingFolder, opts) {
  if (opts == null) {
    opts = {};
  }
  if (opts.username == null) {
    throw new PluginError(PLUGIN_NAME, 'username required');
  }
  if (opts.password == null) {
    throw new PluginError(PLUGIN_NAME, 'password required');
  }
  return through.obj(function(file, enc, cb) {
    var self;
    if (file.isNull()) {
      return cb();
    }
    self = this;
    return api.putFile(startingFolder, file, opts, function(err, upyunInfo) {
      if (err != null) {
        if (opts.verbose) {
          log("" + PLUGIN_NAME + ": upload " + file.relative + " errors(" + err + ")");
        }
        return cb(err);
      }
      if (opts.verbose) {
        log("" + PLUGIN_NAME + ": uploaded " + file.relative, upyunInfo);
      }
      return cb();
    });
  });
};
