/**
 * This file is useful for mocha tests.
 * To use, run mocha --require coffee-coverage/register-istanbul
 */
var coffeeCoverage = require('./');
var path = require('path');
var coverageVar = coffeeCoverage.findIstanbulVariable();
var writeOnExit = coverageVar == null ? true : null;

var outFile = writeOnExit ? ((_ref = process.env.COFFEECOV_OUT) != null ? _ref : 'coverage/coverage-coffee.json') : null
if (process.env.NYC_CONFIG) {
    var config = JSON.parse(process.env.NYC_CONFIG);
    outFile = path.resolve(config.cwd, config.tempDirectory, process.env.NYC_ROOT_ID + '.json');
}

coffeeCoverage.register({
    instrumentor: 'istanbul',
    basePath: process.cwd(),
    exclude: ['/test', '/node_modules', '/.git'],
    coverageVar: coverageVar,
    writeOnExit: outFile,
    initAll: (_ref = process.env.COFFEECOV_INIT_ALL) != null ? (_ref === 'true') : true
});