/**
 * This file is useful for mocha tests
 * To use it, run mocha --require coffee-coverage/register --reporter html-cov > coverage.html
 */
require('./').register({
  basePath: process.cwd(),
  path: 'relative',
  exclude: ['/test', '/node_modules', '/.git'],
});
