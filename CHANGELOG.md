# coffee-coverage Changelog

### v0.0.2

 - Added '-i' option to specify an 'init' file.
 - Changed return value of CoverageInstrumentor.instrumentCoffee - now returns an
   "init" and a "js" which must be concatenated to get fully instrumented source.

### v0.0.3

  -Fix bug which stopped -i option from working.

### v0.0.5

  -Fix bug in "abbr" paths when path is absolute (starts with "/").

### v0.0.6

  -Bug fix from [dstokes](https://github.com/dstokes) for recursively creating directories.