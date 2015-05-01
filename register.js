/**
 * This file is useful for mocha tests.
 * To use it, run mocha --require coffee-coverage/register --reporter html-cov > coverage.html
 */
require('./').register({
    instrumentor: 'jscoverage',
    basePath: process.cwd(),
    path: 'relative',
    exclude: ['/test', '/node_modules', '/.git'],
    coverageVar: '_$jscoverage',
    initAll: (_ref = process.env.COFFEECOV_INIT_ALL) != null ? (_ref === 'true') : true
});
