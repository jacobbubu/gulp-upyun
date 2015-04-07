var PLUGIN_NAME, PluginError, api, log, path, ref, through;

ref = require('gulp-util'), PluginError = ref.PluginError, log = ref.log;

api = require('./upyunAPI');

through = require('through2');

path = require('path');

PLUGIN_NAME = 'gulp-upyun-rimfaf';

module.exports = function(filePath, opts, cb) {
  var deleteDirectly, finish;
  if (typeof filePath === 'string') {
    deleteDirectly = true;
    filePath = filePath[0] !== '/' ? '/' + filePath : filePath;
    if (typeof opts === 'function') {
      opts = {};
      cb = opts;
    } else {
      if (opts == null) {
        opts = {};
      }
      if (cb == null) {
        cb = function() {};
      }
    }
  } else {
    deleteDirectly = false;
    opts = filePath != null ? filePath : {};
  }
  if (opts.username == null) {
    throw new PluginError(PLUGIN_NAME, 'username required');
  }
  if (opts.password == null) {
    throw new PluginError(PLUGIN_NAME, 'password required');
  }
  finish = function(filepath, err, cb) {
    if (err != null) {
      if (opts.verbose) {
        log(PLUGIN_NAME + ": delete " + filepath + " errors(" + err + ")");
      }
      return cb(err);
    } else {
      if (opts.verbose) {
        log(PLUGIN_NAME + ": deleted " + filepath);
      }
      return cb();
    }
  };
  if (deleteDirectly) {
    if (filePath.slice(-1) === '/') {
      return api.delFolder(filePath, opts, function(err) {
        return finish(filePath, err, cb);
      });
    } else {
      return api.delFileOrDir(filePath, opts, function(err) {
        return finish(filePath, err, cb);
      });
    }
  } else {
    return through.obj(function(file, enc, cb) {
      if (file.stat.isFile()) {
        return api.delFileOrDir(file.path, opts, function(err) {
          return finish(file.relative, err, cb);
        });
      } else {
        return api.delFolder(file.path, opts, function(err) {
          return finish(file.relative, err, cb);
        });
      }
    });
  }
};
