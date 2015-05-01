exports.register = require './register'
exports.CoverageInstrumentor = require('./coffeeCoverage').CoverageInstrumentor
exports.findIstanbulVariable = require('./instrumentors/Istanbul').findIstanbulVariable

# Add 'version', 'author', and 'contributors' to our exports
require('pkginfo') module, 'version', 'author', 'contributors'

