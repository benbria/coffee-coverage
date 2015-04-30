Benbria CoffeeCoverage
======================

Instruments CoffeeScript files for code coverage.  Compiles .coffee files to .js files, and adds JSCoverage or Istanbul style instrumentation for the original coffee script source.

[![NPM](https://nodei.co/npm/coffee-coverage.png?downloads=true&downloadRank=true&stars=true)](https://npmjs.org/package/coffee-coverage)

Features
--------

* Support for [Istanbul](./docs/HOWTO-istanbul.md) style instrumentation.
* Support for [JSCoverage](./docs/HOWTO-jscoverage.md) style insturmentation.
* Support for [Streamline compiler](./docs/streamline.md) style insturmentation.
* Dynamic instrumentation - instrument your code at run time.
* [Precompiled instrumentation](./docs/cli.md).

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

How it Works
------------
See the [Design](https://github.com/benbria/coffee-coverage/wiki/Design) page on the Wiki.

