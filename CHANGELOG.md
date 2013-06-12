# coffee-coverage Changelog

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



