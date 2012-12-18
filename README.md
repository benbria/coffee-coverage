Benbria CoffeeCoverage
======================

Compiles .coffee files to .js files, and adds [JSCoverage](http://siliconforks.com/jscoverage/)
style instrumnetation for the original coffee script source.

Contents
--------

*   [Installation and a Quick Intro](#installation-and-a-quick-intro)
*   [What it Does](#what-it-does)
*   [How it Works](#how-it-works)
*   [Using with Mocha and Node.js](#using-with-mocha-and-nodejs)
*   [Some Weirdness with Line Numbers](#some-weirdness-with-line-numbers)
*   [Detailed Usage](#detailed-usage)


What it Does
------------

Benbria CoffeeCoverage takes a collection of .coffee files, and produces .js files which have been
instrumented to record how many times each line is executed.  Given a file "hello.coffee":

    console.log "Hello World"

It produces output that looks something like this (edited slightly for brevity and readability):

    // coffeecoverage generated initialization
    if (! _$jscoverage["hello.coffee"]) {
        _$jscoverage["hello.coffee"] = [];
        _$jscoverage["hello.coffee"][1] = 0;
    }
    _$jscoverage["hello.coffee"].source = ["console.log \"Hello World\"", ""];

    (function() {

      _$jscoverage["hello.coffee"][1]++; // Count that we're executing line #1
      console.log("Hello World");

    }).call(this);

The output is intentionally similar to that of [JSCoverage](http://siliconforks.com/jscoverage/),
so that your source can be used with existing coverage-analysis tools.


Installation and a Quick Intro
------------------------------

Install with:

    npm install -g coffee-coverage

Given a directory "source" full of .coffee files, run:

    coffeecoverage ./source ./dest

This will recursively find all the .coffee files in the "source" directory, and produce .js files
in the "dest" directory.  Note that you can compile in-place with:

    coffeecoverage ./source ./source


How it Works
------------
See the [Design](https://github.com/benbria/coffee-coverage/wiki/Design) page on the Wiki.


Using with Mocha and Node.js
----------------------------

At Benbria, we use CoffeeCoverage to find out how much coverage we get from our unit tests.  Our
process works like this; first we make a copy of our code base:

    cd project
    mkdir /tmp/coverage
    tar -cf - . | (cd /tmp/coverage && tar -xf -)
    cd /tmp/coverage

Then we instrument it in-place.  We exclude the "test" directory, since we don't want coverage of
our actual test code:

    coffeecoverage --initfile init.js --exclude node_modules,.git,test --path abbr . .

We don't have to delete the .coffee files, since when we `require 'foo'`, node will preferentially
load the foo.js file over the foo.coffee file.  coffeecoverage nicely gives us the number of lines
it instrumented - this is handy, because if we never `require` a given file from our tests, it
won't show up in the mocha report.

Next we run our tests:

    mocha --require init.js --reporter html-cov --compilers coffee:coffee-script test/*Test.coffee

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

We have three statements we could annotate here; the "if" itself, the call to y, and the call to z.
The problem is that both the "if" an the call to "y()" are on the same line of CoffeeScript source.
If we annotate both the "if" and the "y()", then if `x` is true, we will count two executions of the
first line of the CoffeeScript, even though we've only run this chunk of CoffeeScript once.

CoffeeCoverage tries to work around this by only instrumenting the first statement it finds on a
line, so in the above example, we'd annotate the "if" and the "z()", but not the "y()".

Detailed Usage
--------------

Usage: `coffeecoverage [-h] [-v] [-c name] [-e filenames] [-i initfile] [--path pathtype] src dest`

`src` and `dest` are the source file or directory and destination file or directory, respectively.
If `src` is a .coffee file, then coffeecoverage will instrument the file and write the result to
`dest` (e.g. `coffeecoverage a.coffee a.js`.)  If `src` is a directory, then coffeecoverage will
recursively walk through `src` finding .coffee files, and writing them into the `dest`, creating
any subdirectories in `dest` as required.  If `src` and `dest` are the same directory, then all the
.coffee files in `src` will have .js files written alongside them.

### Optional arguments:

#### -c, --coverageVar

By default, coffeecoverage will instrument source files with the global variable "_$jscoverage".
This is done to mimic JSCoverage.  You can rename this variable by using this option.

#### -i, --initfile

Specifies an "initfile" which all global initalization is written to.  This is handy for testing
with mocha.  If you `require` the initfile, then mocha reports will show coverage of all files in
your project, even files which were never required anywhere.

#### -e, --exclude

Gives a comma delimited list of files and directories to exclude from processing.  This defaults
to 'node_modules,.git', since neither of these are directories you probably want to be
instrumenting.  If you want to also exclude your "test" directory, you might run coffeecoverage
with:

    coffeecoverage --exclude 'node_modules,.git,test' ...

#### --path

Path can be given one of three different parameters:

 - `none` is the default - if coffeecoverage reads a file from "src/models/user.coffee", then
   the instrumented code will use the filename "user.coffee".  This works well provided you
   don't reuse filenames elsewhere in your code.  Note that if there is a name collision between
   two files in different subdirectories, coffeecoverage will append a something to the
   end of one to make it unique, otherwise coverage data from one file would interfere with data
   from another.
 - `abbr` will use abbreviated path names; a file from "src/models/user.coffee" will be
   instrumented as "s/m/user.coffee".
 - `relative` will use the full relative pathname; "src/models/user.coffee".

Paths are always relative to the `src` directory provided on the command line.
