# coffee-coverage Changelog

### v0.0.2

 - Added '-i' option to specify an 'init' file.
 - Changed return value of CoverageInstrumentor.instrumentCoffee - now returns an
   "init" and a "js" which must be concatenated to get fully instrumented source.