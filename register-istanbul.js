/**
 * This file is useful for mocha tests
 * To use it, run mocha --require coffee-coverage/register --reporter html-cov > coverage.html
 */
require('./').register({
  basePath: process.cwd(),
  path: 'absolute',
  exclude: ['/test', '/node_modules', '/.git'],
  coverageVar: '$_coffeeIstanbul',
  instrumentor: 'istanbul',
  writeOnExit: 'coverage/coverage-coffee.json'
});