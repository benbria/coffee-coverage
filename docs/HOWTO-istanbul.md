Quick Start
-----------

Assuming you have a coffee-script project with tests cases stored in /test, and you are using
mocha to run your unit tests, `cd` to your project and run:

    npm install --save-dev coffee-coverage
    npm install --save-dev istanbul
    ./node_modules/.bin/mocha --recursive \
          --compilers coffee:coffee-script/register \
          --require coffee-coverage/register-istanbul \
          test
    ./node_modules/.bin/istanbul report

You should now have a coverage report in ./coverage/lcov-report/index.html.

This should work for the majority of projects, but if it doesn't quite do what you want, you can
tweak a few things with environment variables, or you can set up
[custom options with a loader](#writing-a-custom-loader).

Not using mocha?  See [precompiling files](#precompiling-files) below to see how to instrument
files at compile time.

You can control how `register-istanbul.js` will work with the following environment variables:

* `COFFEECOV_OUT` - (defaults to 'coverage/coverage-coffee.json') location to write coverage JSON
  report when your process exits.
* `COFFEECOV_INIT_ALL` - (defaults to 'true') if set to 'true', then coffee-coverage will
  recursively walk through the current folder looking for .coffee files at startup, so you will see
  0% coverage for files that are never loaded.  coffee-coverage will ignore the './test',
  './node_modules', and './.git' folders.  If you want to ignore other folders, see
  [#how to write a custom loader](#writing-a-custom-loader).

Run with NPM
============

Save your mocha options in `/test/mocha.opts`:

    --compilers coffee:coffee-script/register
    --require coffee-coverage/register-istanbul
    --recursive

In package.json, add:

    "scripts": {
        "test": "npm run build && mocha && istanbul report"
    }

now you can run `npm test` to run your tests and generate a coverage report.

Writing a Custom Loader
=======================

If the defaults in `coffee-coverage/register-istanbul` don't work for you, you can write a custom
loader.  Save this in "coffee-coverage-loader.js":

    require('coffee-coverage').register({
      basePath: process.cwd(),
      exclude: ['/test', '/node_modules', '/.git'],
      instrumentor: 'istanbul',
      coverageVar: '$_coffeeIstanbul',
      writeOnExit: 'coverage/coverage-coffee.json',
      initAll: true
    });

Then when you run mocha, use `--require ./coffee-coverage-loader.js`.

Precompiling Files
------------------

TODO: Figure out how this is going to work.  :)
