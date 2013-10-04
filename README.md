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

    // coffeeCoverage generated initialization
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

    coffeeCoverage ./source ./dest

This will recursively find all the .coffee files in the "source" directory, and produce .js files
in the "dest" directory.  Note that you can compile in-place with:

    coffeeCoverage ./source ./source


How it Works
------------
See the [Design](https://github.com/benbria/coffee-coverage/wiki/Design) page on the Wiki.


Using with Mocha and Node.js
----------------------------

### Dynamic Compilation

There are two ways to use coffeeCoverage as part of your unit tests.  First, if you run your
tests directly on your .coffee files, you can register coffeeCoverage to dynamically compile
.coffee (and even ._coffee if you're using [streamlinejs](https://github.com/Sage/streamlinejs))
files.  For example, create a "register-handlers.js":

    # If you're using with streamline, you *must* register streamline first:
    require('streamline').register({});

    #  Register coffee-coverage if coverage is enabled.
    if(process.env.COVERAGE) {
        require('coffee-coverage').register({
            path: 'abbr',
            basePath: __dirname,
            exclude: ['/test', '/node_modules', '/.git'],
            initAll: true,
            streamlinejs: true
        });
    }

Note we set the "basePath" to the root of our project.  This can be a path which is relative to
`__dirname` (e.g. `__dirname + "/.."`).

Note that streamline support is "experimental" right now (i.e. it might break at any moment
because we're using undocumented features in streamlinejs) so to turn it on, you have to
explicitly pass 'streamlinejs: true' as an option.

Then, run your tests:

    COVERAGE=true mocha --require register-handlers.js --reporter html-cov ...

### Static Compilation

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

Static compilation does not currently support streamline.

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

because otherwise it would be unable to annotate the `if(y)` statement.

Detailed Usage
--------------

Usage: `coffeeCoverage [-h] [-v] [-c name] [-e filenames] [-i initfile] [--path pathtype] src dest`

`src` and `dest` are the source file or directory and destination file or directory, respectively.
If `src` is a .coffee file, then coffeecoverage will instrument the file and write the result to
`dest` (e.g. `coffeeCoverage a.coffee a.js`.)  If `src` is a directory, then coffeecoverage will
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
instrumenting.  If you want to also exclude your "test" directory, you might run coffeeCoverage
with:

    coffeeCoverage --exclude 'node_modules,.git,test' ...

#### --path

Path can be given one of three different parameters:

 - `none` is the default - if coffeeCoverage reads a file from "src/models/user.coffee", then
   the instrumented code will use the filename "user.coffee".  This works well provided you
   don't reuse filenames elsewhere in your code.  Note that if there is a name collision between
   two files in different subdirectories, coffeecoverage will append a something to the
   end of one to make it unique, otherwise coverage data from one file would interfere with data
   from another.
 - `abbr` will use abbreviated path names; a file from "src/models/user.coffee" will be
   instrumented as "s/m/user.coffee".
 - `relative` will use the full relative pathname; "src/models/user.coffee".

Paths are always relative to the `src` directory provided on the command line.
