###
    credential.js is ignored from git repo.
    that should be is locatied in the project root with following content

    module.exports = {
        user: 'username/spaceName',
        password: 'your password'
    }
###
module.exports.credential = require './credential'