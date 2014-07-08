var PluginError, api, es, log, _ref;

_ref = require('gulp-util'), PluginError = _ref.PluginError, log = _ref.log;

es = require('event-stream');

api = require('./upyunAPI');

module.exports = function(ourGlob, negatives, opts) {
  if (!Array.isArray(negatives)) {
    opts = negatives != null ? negatives : {};
    negatives = [];
  } else {
    if (negatives == null) {
      negatives = [];
    }
    if (opts == null) {
      opts = {};
    }
  }
  if (opts.username == null) {
    throw new PluginError('gulp-upyun-src', 'username required');
  }
  if (opts.password == null) {
    throw new PluginError('gulp-upyun-src', 'password required');
  }
  return es.readable(function(count, cb) {
    var stream;
    stream = this;
    return api.getAllMatchedFiles(ourGlob, negatives, opts, function(err, vfs) {
      if (err != null) {
        return cb(err);
      }
      vfs.forEach(function(vf) {
        return stream.emit('data', vf);
      });
      stream.emit('end');
      return cb();
    });
  });
};
