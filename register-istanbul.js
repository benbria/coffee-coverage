/**
 * This file is useful for mocha tests
 * To use it, run mocha --require coffee-coverage/register-istanbul
 */
require('./').register({
  basePath: process.cwd(),
  exclude: ['/test', '/node_modules', '/.git'],
  instrumentor: 'istanbul',
  coverageVar: '$_coffeeIstanbul',
  writeOnExit: (_ref = process.env.COFFEECOV_OUT) != null ? _ref : 'coverage/coverage-coffee.json',
  initAll: (_ref = process.env.COFFEECOV_INIT_ALL) != null ? (_ref === 'true') : true,
});