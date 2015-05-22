var DEFAULT_HOST, File, Glob, Minimatch, STAT_FALSE, STAT_TRUE, Stat, api, async, getHttpParams, glob2base, md5, path, ref, request, sign, streamToBuffer, through, toArray, url;

Glob = require('glob').Glob;

glob2base = require('glob2base');

url = require('url');

path = require('path');

async = require('async');

File = require('vinyl');

request = require('request');

Minimatch = require('minimatch').Minimatch;

Stat = require('fs').Stats;

through = require('through2');

ref = require('./upSign'), sign = ref.sign, md5 = ref.md5;

toArray = require('stream-to-array');

DEFAULT_HOST = 'http://v0.api.upyun.com';

STAT_TRUE = function() {
  return true;
};

STAT_FALSE = function() {
  return false;
};

getHttpParams = function(host, remotePath, opts, contentLength, method) {
  var dateHeader, fullUrl;
  if (contentLength == null) {
    contentLength = 0;
  }
  if (method == null) {
    method = 'GET';
  }
  dateHeader = new Date().toUTCString();
  fullUrl = url.resolve(host, remotePath);
  return {
    url: fullUrl,
    headers: {
      authorization: ("UpYun " + opts.username + ":") + sign(method, encodeURI(remotePath), opts.password, dateHeader, contentLength),
      date: dateHeader
    }
  };
};

api = {};

api.getAllMatchedFiles = function(emitter, ourGlob, negatives, opts, cb) {
  var getOneFolderInfo, globber, host, mm, negativeMms, ref1, startingFolder;
  if (opts == null) {
    opts = {};
  }
  if (negatives == null) {
    negatives = [];
  }
  ourGlob = path.join('/', ourGlob);
  globber = new Glob(ourGlob);
  opts.base = glob2base(globber);
  if (opts.read == null) {
    opts.read = true;
  }
  if (opts.buffer == null) {
    opts.buffer = true;
  }
  host = (ref1 = opts.host) != null ? ref1 : DEFAULT_HOST;
  startingFolder = opts.base;
  mm = new Minimatch(ourGlob);
  negativeMms = [];
  negativeMms = negatives.map(function(n) {
    return new Minimatch(n);
  });
  getOneFolderInfo = function(folder, cb) {
    var getPagedResult;
    getPagedResult = function(cb) {
      var oneRequest;
      oneRequest = function(iter, initial, cb) {
        var params;
        params = getHttpParams(host, folder, opts);
        if (iter != null) {
          params.headers['x-list-iter'] = iter;
        }
        return request(params, function(err, res, body) {
          var hasMore;
          if (err != null) {
            return cb(err);
          }
          if (res.statusCode !== 200) {
            return cb({
              statusCode: res.statusCode,
              body: body,
              filename: folder
            });
          }
          iter = res.headers['x-upyun-list-iter'];
          hasMore = (iter != null) && iter.toLowerCase() !== 'none';
          if (body[body.length - 1] !== '\n') {
            body += '\n';
          }
          initial += body;
          if (hasMore) {
            return oneRequest(iter, initial, cb);
          } else {
            return cb(null, initial);
          }
        });
      };
      return oneRequest(null, '', cb);
    };
    return getPagedResult(function(err, upYunResult) {
      var files;
      if (!upYunResult) {
        return cb();
      }
      files = upYunResult.split('\n');
      return async.eachLimit(files, 8, function(f, cb) {
        var ctime, filePath, isFile, length, name, p, ref2, stat, vf;
        if (!f.trim()) {
          return cb();
        }
        ref2 = f.split('\t'), name = ref2[0], isFile = ref2[1], length = ref2[2], ctime = ref2[3];
        isFile = isFile === 'N';
        filePath = path.join(folder, name);
        if (mm.match(filePath) && (negativeMms.every(function(nmm) {
          return nmm.match(filePath);
        }))) {
          stat = new Stat;
          stat.isFile = isFile ? STAT_TRUE : STAT_FALSE;
          stat.isDirectory = isFile ? STAT_FALSE : STAT_TRUE;
          stat.isBlockDevice = STAT_FALSE;
          stat.isCharacterDevice = STAT_FALSE;
          stat.isSymbolicLink = STAT_FALSE;
          stat.isFIFO = STAT_FALSE;
          stat.isSocket = STAT_FALSE;
          stat.ctime = stat.mtime = stat.atime = new Date(ctime * 1000);
          stat.size = Number(length);
          vf = new File({
            cwd: '/',
            base: startingFolder,
            path: filePath,
            contents: null,
            stat: stat
          });
          if (isFile) {
            if (opts.read) {
              p = getHttpParams(host, filePath, opts);
              if (opts.buffer) {
                p.encoding = null;
                return request(p, function(err, res, body) {
                  if (err != null) {
                    return cb(err);
                  }
                  if (res.statusCode !== 200) {
                    return cb({
                      statusCode: res.statusCode,
                      body: body,
                      filename: filePath
                    });
                  }
                  vf.contents = body;
                  emitter.emit('data', vf);
                  return cb();
                });
              } else {
                vf.contents = request(p).pipe(through());
                emitter.emit('data', vf);
                return cb();
              }
            } else {
              emitter.emit('data', vf);
              return cb();
            }
          } else {
            emitter.emit('data', vf);
            return getOneFolderInfo(filePath, cb);
          }
        } else if (isFile) {
          return cb();
        } else {
          return getOneFolderInfo(filePath, cb);
        }
      }, function(err) {
        return cb(err);
      });
    });
  };
  return getOneFolderInfo(startingFolder, function(err) {
    if (err != null) {
      return cb(err);
    } else {
      return cb();
    }
  });
};

streamToBuffer = api.streamToBuffer = function(stream, cb) {
  return toArray(stream, function(err, arr) {
    if (err != null) {
      return cb(err);
    }
    return cb(null, Buffer.concat(arr));
  });
};

api.putFile = function(startingFolder, file, opts, cb) {
  var data, length, uploadToServer;
  if (file.isNull()) {
    return cb();
  }
  uploadToServer = function(length, data, cb) {
    var folder, host, params, ref1, ref2;
    host = (ref1 = opts.host) != null ? ref1 : DEFAULT_HOST;
    folder = path.join('/', startingFolder, file.relative);
    params = getHttpParams(host, folder, opts, length, 'PUT');
    if (data.length > 0) {
      params.body = data;
    }
    params.headers.mkdir = (ref2 = opts.mkdir) != null ? ref2 : true;
    params.headers['content-length'] = length;
    if (opts['content-type'] != null) {
      params.headers['content-type'] = opts['content-type'];
    }
    if (opts.md5) {
      params.headers['content-md5'] = md5(data);
    }
    return request.put(params, function(err, res, body) {
      var result;
      if (err != null) {
        return cb(err);
      }
      if (res.statusCode !== 200) {
        return cb({
          statusCode: res.statusCode,
          body: body,
          filename: file.path
        });
      }
      result = {
        'x-upyun-width': res.headers['x-upyun-width'],
        'x-upyun-height': res.headers['x-upyun-height'],
        'x-upyun-frames': res.headers['x-upyun-frames'],
        'x-upyun-file-type': res.headers['x-upyun-file-type']
      };
      return cb(null, result);
    });
  };
  if (file.isBuffer()) {
    data = file.contents;
    length = data.length;
    return uploadToServer(length, data, function(err, res) {
      return cb(err, res);
    });
  } else if (file.isStream()) {
    return streamToBuffer(file.contents, function(err, data) {
      if (err != null) {
        return cb(err);
      }
      return uploadToServer(data.length, data, function(err, res) {
        return cb(err, res);
      });
    });
  } else {
    return cb();
  }
};

api.delFileOrDir = function(filePath, opts, cb) {
  var host, params, ref1;
  host = (ref1 = opts.host) != null ? ref1 : DEFAULT_HOST;
  params = getHttpParams(host, filePath, opts, 0, 'DELETE');
  return request.del(params, function(err, res, body) {
    if (err != null) {
      return cb(err);
    }
    switch (res.statusCode) {
      case 200:
        return cb();
      case 404:
        return cb();
      default:
        return cb({
          statusCode: res.statusCode,
          body: body,
          filename: filePath
        });
    }
  });
};

api.delFolder = function(startingfolder, opts, cb) {
  var deleteOneFolder, host, ref1;
  host = (ref1 = opts.host) != null ? ref1 : DEFAULT_HOST;
  deleteOneFolder = function(folder, cb) {
    var params;
    if (folder.slice(-1) !== '/') {
      folder = folder + '/';
    }
    params = getHttpParams(host, folder, opts);
    return request(params, function(err, res, body) {
      var files;
      if (err != null) {
        return cb(err);
      }
      if (res.statusCode === 404) {
        return cb();
      }
      if (res.statusCode !== 200) {
        return cb({
          statusCode: res.statusCode,
          body: body,
          filename: folder
        });
      }
      if (!body) {
        return api.delFileOrDir(folder, opts, cb);
      }
      files = body.split('\n');
      return async.eachLimit(files, 8, function(f, cb) {
        var ctime, filePath, isFile, length, name, ref2;
        if (!f) {
          return cb();
        }
        ref2 = f.split('\t'), name = ref2[0], isFile = ref2[1], length = ref2[2], ctime = ref2[3];
        isFile = isFile === 'N';
        filePath = path.join(folder, name);
        if (isFile) {
          return api.delFileOrDir(filePath, opts, cb);
        } else {
          return deleteOneFolder(filePath, cb);
        }
      }, function(err) {
        return api.delFileOrDir(folder, opts, cb);
      });
    });
  };
  return deleteOneFolder(startingfolder, cb);
};

module.exports = api;
