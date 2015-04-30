Running with [JSCoverage](http://siliconforks.com/jscoverage/)
---------------------------------------------------------------

Contents
========

* [Quick Start with Mocha](#quick-start-with-mocha)
  * [Run with NPM](#run-with-npm)
  * [Writing a Custom Loader](#writing-a-custom-loader)
  * [Precomiled Source](#precompiled-source)
* [Some Weirdness with Line Numbers](#some-weirdness-with-line-numbers)

Quick Start with Mocha
----------------------

Assuming you have a coffee-script project with tests cases stored in /test, and you are using
mocha to run your unit tests, `cd` to your project and run:

    npm install --save-dev coffee-coverage
    mocha --recursive \
        --require coffee-coverage/register \
        --reporter html-cov \
        test > coverage.html

This will run your unit tests, instrument them with JSCoverge style instrumentation, and write
a coverage report to coverage.html.

This should work for the majority of projects, but if it doesn't quite do what you want, you can
set [custom options with a loader](#writing-a-custom-loader).

You can control how `coffee-coverage/register` will work with the following environment variables:

* `COFFEECOV_INIT_ALL` - (defaults to 'true') if set to 'true', then coffee-coverage will
  recursively walk through the current folder looking for .coffee files at startup, so you will see
  0% coverage for files that are never loaded.  coffee-coverage will ignore the './test',
  './node_modules', and './.git' folders.  If you want to ignore other folders, see
  [#how to write a custom loader](#writing-a-custom-loader).

Run with NPM
============

Save your mocha options in `/test/mocha.opts`:

    --compilers coffee:coffee-script/register
    --recursive

In package.json, add:

    "scripts": {
        "coverage": "mocha --require coffee-coverage/register --reporter html-cov > coverage.html"
    }

now you can run `npm run coverage` to run your tests and generate a coverage report.

Writing a Custom Loader
=======================

If the defaults in `coffee-coverage/register-istanbul` don't work for you, you can write a custom
loader.  Save this in "coffee-coverage-loader.js":

    require('coffee-coverage').register({
      instrumentor: 'jscoverage',
      basePath: process.cwd(),
      path: 'relative'
      exclude: ['/test', '/node_modules', '/.git'],
      coverageVar: '_$jscoverage',
      initAll: true
    });

Then when you run mocha, use `--require ./coffee-coverage-loader.js`.

Precomiled Source
=================

Alternatively, you can use coffeeCoverage to statically compile your code with instrumentation:

    # Compile everything except the test directory with coffeeCoverage
    coffeeCoverage --initfile ./lib/init.js --exclude test --path abbr ./src ./lib
    # Compile the test directory with regular coffee-script
    coffee -o ./lib/test ./src/test

This also writes an "lib/init.js" which initializes all the execution counts to 0.  This is handy,
because otherwise if we never `require` a given module, that module's counts won't show up at all
in the code coverage report, which might overly inflate our code coverage percentage.  Next we run
our tests:

    mocha --require ./lib/init.js --reporter html-cov ./lib/test/*

Some Weirdness with Line Numbers
--------------------------------

This snippet of CoffeeScript:

    if x then y() \
         else z()

gets compile to this snippet of JavaScript:

    if (x) {
      y();
    } else {
      z();
    }

We have three statements we could instrument here; the "if" itself, the call to y, and the call to z.
The problem is that both the "if" an the call to "y()" are on the same line of CoffeeScript source.
If we instrument both the "if" and the "y()", then if `x` is true, we will count two executions of the
first line of the CoffeeScript, even though we've only run this chunk of CoffeeScript once.

CoffeeCoverage tries to work around this by only instrumenting the first statement it finds on a
line, so in the above example, we'd instrument the "if" and the "z()", but not the "y()".

Also, it's worth noting a minor difference in the way coffee-coverage compiles statements.  The
following coffee code:

    if x
      a()
    else if y
      b()

Would normally compile to:

    if(x) {
      a();
    } else if(y) {
      b();
    }

coffeeCoverage will instead compile this to:

    if(x) {
      a();
    } else {
      if(y) {
        b();
      }
    }

because otherwise it would be unable to instrument the `if(y)` statement.
