Instrumenting Files at Compile Time
-----------------------------------

Given a directory "src" full of .coffee files, run:

    coffeeCoverage ./src ./lib

This will recursively find all the .coffee files in the "src" directory, and produce .js files
in the "lib" directory.  Note that you can compile in-place with:

    coffeeCoverage ./src ./src

You can specify the style of instrumentation you want to use:

    coffeeCoverage --inst istanbul ./src ./lib-istanbul
    coffeeCoverage --inst jscoverage ./src ./lib-jscoverage

Detailed Usage
--------------

Usage: `coffeeCoverage [options] src dest`

`src` and `dest` are the source file or directory and destination file or directory, respectively.
If `src` is a .coffee file, then coffee-coverage will instrument the file and write the result to
`dest` (e.g. `coffeeCoverage a.coffee a.js`.)  If `src` is a directory, then coffee-coverage will
recursively walk through `src` finding .coffee files, and writing them into the `dest`, creating
any subdirectories in `dest` as required.  If `src` and `dest` are the same directory, then all the
.coffee files in `src` will have .js files written alongside them.

### Optional arguments:

#### -h

Print help.

#### -v

Print the version number to stdout and quit.

#### -c, --coverageVar

By default, coffee-coverage will instrument source files with the global variable `_$jscoverage`
(for jscoverage) or `_$coffeeIstanbul` (for istanbul).  You can set whatever variable name you'd
like by using this option.

#### -t, --inst

Set the type of instrumentation to generate. Valid options are: jscoverage (default), istanbul

#### -i, --initfile

Specifies an "initfile" which all global initialization is written to.  This is handy for testing
with mocha and jscoverage.  If you `require` the initfile, then mocha's `html-cov` reporter will
show coverage of all files in your project, even files which were never run.

#### -e, --exclude

Gives a comma delimited list of files and directories to exclude from processing.  This defaults
to 'node_modules,.git', since neither of these are directories you probably want to be
instrumenting.  If you want to also exclude your "test" directory, you might run coffeeCoverage
with:

    coffeeCoverage --exclude 'node_modules,.git,test' ...

You can also use globs. If you have your specs next to your code you might e.g. use:

    coffeeCoverage --exclude 'node_modules,.git,**/*.spec.coffee'

#### --path

Only used when `--inst jscoverage` is specified.  Path can be given one of three different
parameters:

 - `none` is the default - if coffeeCoverage reads a file from "src/models/user.coffee", then
   the instrumented code will use the filename "user.coffee".  This works well provided you
   don't reuse filenames elsewhere in your code.  Note that if there is a name collision between
   two files in different subdirectories, coffee-coverage will append a something to the
   end of one to make it unique, otherwise coverage data from one file would interfere with data
   from another.
 - `abbr` will use abbreviated path names; a file from "src/models/user.coffee" will be
   instrumented as "s/m/user.coffee".
 - `relative` will use the full relative pathname; "src/models/user.coffee".

Paths are relative to the `--basepath` option, or if not specified, then to the `src` directory
provided on the command line.

#### --basePath

Specify the root folder of the project.
