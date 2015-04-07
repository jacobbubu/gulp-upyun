var PluginError, api, es, log, ref;

ref = require('gulp-util'), PluginError = ref.PluginError, log = ref.log;

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
    return api.getAllMatchedFiles(stream, ourGlob, negatives, opts, function(err) {
      if (err != null) {
        if (typeof err === 'object' && err.statusCode === 404) {
          stream.emit('end');
          return cb();
        } else {
          return cb(err);
        }
      }
      stream.emit('end');
      return cb();
    });
  });
};
