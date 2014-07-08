var crypto, md5;

crypto = require('crypto');

md5 = module.exports.md5 = function(value) {
  var checksum;
  checksum = crypto.createHash('md5');
  checksum.update(value != null ? value : '');
  return checksum.digest('hex');
};

module.exports.sign = function(method, uri, password, date, contentLength) {
  if (contentLength == null) {
    contentLength = 0;
  }
  if (date == null) {
    date = new Date().toUTCString();
  }
  return md5([method, uri, date, contentLength, md5(password)].join('&'));
};
