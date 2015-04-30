exports.register = require './register'
exports.CoverageInstrumentor = require('./coffeeCoverage').CoverageInstrumentor

# Add 'version', 'author', and 'contributors' to our exports
require('pkginfo') module, 'version', 'author', 'contributors'

