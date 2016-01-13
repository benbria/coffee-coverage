# coffee-coverage Changelog

### v1.0.0
  - [#71: Accept globs as excludes](https://github.com/benbria/coffee-coverage/pull/71) Many thanks to
    [dbartholomae](https://github.com/dbartholomae) for this much requested feature.  Note that excludes will still
    match if they are prefixes (so you can still use /node_modules to eliminate everything in the /node_modules
    folder), but you can also use globs here.

### v0.7.0
  - [#64: Add `postProcessors` option to `register()`](https://github.com/benbria/coffee-coverage/pull/64) and deprecate `streamlinejs` option.

### v0.5.3
  - [#42: Fix the 0% coverage for files that are never loaded](https://github.com/benbria/coffee-coverage/pull/42)

### v0.5.2
  - Fix weird corner case if statement.
  - Better streamline support.
  - Add support for caching files between runs.

### v0.5.1
  - Fix for istanbul instrumentation for `if` expressions that are implicit returns and are missing
    an `else`.

### v0.5.0
  - Added support for [Istanbul](./docs/HOWTO-istanbul.md). (thanks to
    [Carsten Klein](https://github.com/silkentrance) for some help and suggestions.)
  - Added support for pragmas.
  - Dropped support for node.js v0.6.x.
  - `coffee-coverage/register` now instruments all js files in the CWD by default (instead of only
    files which get loaded.)  You can disable this behavior by setting the `COFFEECOV_INIT_ALL`
    environment variable to 'false'.

Breaking changes:
  - `CoverageInstrumentor.instrumentCoffee()` now expects an absolute path for a file.  It will
    probably continue to work, even if you pass a relative path, though.

### v0.4.5
  - Compatibility fix for coffee-script 1.9.1 (thanks [technogeek00](https://github.com/technogeek00))

### v0.4.4

  - Make the behavior of "skip" be consistent between CLI and dynamic compilation.
  - Drop use of Cakefile for builds.

### v0.4.3

  - Add coffee-coverage/register for easier mocha testing (thanks [devongovett](https://github.com/devongovett))

### v0.4.2

  - Fix exclude bug when dynamically instrumenting files.

### v0.4.1

  - Fix async bug when creating new directories (thanks [can3p](https://github.com/can3p)).

### v0.4.0

  - Add support for literate CoffeeScript (thanks [frozenice-](https://github.com/frozenice-)).

### v0.3.0

  - Add support for dynamically compiling .coffee and ._coffee files on the fly.  (Special thanks
    to [sivad77](https://github.com/sivad77) for the suggestion.)
  - Experimental support for [streamlinejs](https://github.com/Sage/streamlinejs).

### v0.2.0

  - Force coffee-script to disable chaining of if/else if statements during compile.  This
    fix is required for coffee-script 1.6.3 and higher.

### v0.1.4

  - Add '--bare' option (thanks [effata](https://github.com/effata)!)

### v0.1.3

  - Update to Coffee-Script >=1.6.2.

### v0.1.2

  - Update to Coffee-Script 1.6.1.

### v0.1.1

  -Ran into a strange bug in Coffee-Script 1.5.0 that's fixed in git, so I switched the dependency
   to the latest Coffee-Script for now.  Basically this:

        done null, _.extend
          myObj: "foo"

   doesn't compile the way you would expect it to.

### v0.1.0

  -Switch over to official Coffee-Script (v.1.5.0 or higher)
  -Bug fix from [vslinko](https://github.com/vslinko) for writing files synchronously.

### v0.0.6

  -Bug fix from [dstokes](https://github.com/dstokes) for recursively creating directories.

### v0.0.5

  -Fix bug in "abbr" paths when path is absolute (starts with "/").

### v0.0.3

  -Fix bug which stopped -i option from working.

### v0.0.2

 - Added '-i' option to specify an 'init' file.
 - Changed return value of CoverageInstrumentor.instrumentCoffee - now returns an
   "init" and a "js" which must be concatenated to get fully instrumented source.
