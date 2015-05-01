Istanbul and JSCoverage-style instrumentation for CoffeeScript files.

Benbria CoffeeCoverage
======================

[![Codeship Build Status](https://codeship.com/projects/015eb880-d22c-0132-7a3a-16c1124d299d/status?branch=master)](https://www.codeship.io/projects/28495)

Instruments CoffeeScript files for code coverage.  Compiles .coffee files to .js files, and adds JSCoverage or Istanbul style instrumentation for the original coffee script source.

[![NPM](https://nodei.co/npm/coffee-coverage.png?downloads=true&downloadRank=true&stars=true)](https://npmjs.org/package/coffee-coverage)

Features
--------

* Native coffee-script instrumentation - not based on source maps.
* Support for [Istanbul](./docs/HOWTO-istanbul.md) style instrumentation.
* Support for [JSCoverage](./docs/HOWTO-jscoverage.md) style insturmentation.
* Support for [Streamline compiler](./docs/streamline.md) style insturmentation.
* Dynamic instrumentation - instrument your code at run time.
* [Precompiled instrumentation](./docs/cli.md).

Quick Start
-----------

Assuming you have a folder named "test" full of mocha tests, which directly loads your .coffee
files, then from your project's folder, run:

    npm install --save-dev coffee-coverage
    npm install --save-dev istanbul
    mocha --recursive \
          --compilers coffee:coffee-script/register \
          --require coffee-coverage/register-istanbul \
          test
    ./node_modules/.bin/istanbul report

You should now have an Istanbul coverage report in ./coverage/lcov-report/index.html.

If this doesn't quite do what you're after, check out our tutorials below:

Tutorials:
----------

* [Mocha and Istanbul Guide](./docs/HOWTO-istanbul.md)
* [Mocha and JSCoverage Guide](./docs/HOWTO-jscoverage.md)
* [Codeship and Coveralls](./docs/HOWTO-codeship-and-coveralls.md)

What it Does
------------

Benbria CoffeeCoverage is a tool for determining the coverage of your unit tests.  It does this
by instrumentating .coffee files to see how often each line, branch, or function is executed.
CoffeeCoverage is capable of producing both [Istanbul](./docs/HOWTO-istanbul.md) and
[JSCoverage](./docs/HOWTO-jscoverage.md) style instrumentation.

Installation and a Quick Intro
------------------------------

Check out the [Istanbul](./docs/HOWTO-istanbul.md) documentation to get setup with CoffeeCoverage
quickly.  There is also a `coffeeCoverage` command line tool which can be used to
[instrument files at compile time](./docs/cli.md).
