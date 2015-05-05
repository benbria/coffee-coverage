path           = require 'path'
fs             = require 'fs'
_              = require 'lodash'

coffeeCoverage = require './coffeeCoverage'
CompiledCache  = require './CompiledCache'

class StringStream
    constructor: () ->
        @data = ""

    write: (data) ->
        @data += data

{mkdirs, excludeFile, getRelativeFilename} = require './utils/helpers'

# Register coffeeCoverage to automatically process '.coffee', '.litcoffee', '.coffee.md' and '._coffee' files.
#
# Note if you're using this in conjunction with
# [streamlinejs](https://github.com/Sage/streamlinejs), you *must* call this function
# after calling `streamline.register()`, otherwise by the time we get the source the
# file will already have been compiled.
#
# Parameters:
# * `options.instrumentor` is the name of the instrumentor to use (see `INSTURMENTORS`.)
#   All options passed in will be passed along to the instrumentor implementation, so
#   instrumentor-specific options may be added to `options` as well.
#
# * `options.coverageVar` gives the name of the global variable to use to store
#   coverage data in. The default coverage variable depends on the `options.instrumentor` used.
#
# * `options.exclude` is an array of files and directories to ignore.  For example, ['/test'] would
#   ignore all files in the test folder.  Defaults to [].
#
# * `options.basePath` the root folder for your project.  If provided, then all excludes will be
#   evaluated relative to this base path. For example, if `options.exclude` is `['/a/b']`, and
#   `options.basePath` is "/Users/jwalton/myproject", then this will prevent
#   coffeeCoverage from traversing "/Users/jwalton/myproject/a/b".  Some instrumentor
#   implementations may strip the `basePath` for readability.
#
# * `options.initAll` - If true, then coffeeCoverage will recursively walk through all
#   subdirectories of `options.basePath` and gather line number information for all CoffeeScript
#   files found.  This way even files which are not `require`d at any point during your test will
#   still be instrumented and reported on.
#
# * `options.writeOnExit` - A file to write a JSON coverage file to on completion.  This will
#   stringify the variable set in `options.coverageVar` and write it to disk.
#
# * `options.streamlinejs` - Enable support for streamlinejs.  You can either pass `true`
#   here, or a set of options to pass on to
#   [transform](https://github.com/Sage/streamlinejs/blob/master/lib/callbacks/transform.md).
#
# * `options.cachePath` - A folder to write instrumented code to.  Subsequent runs will load
#   instrumented code from the cache if the source files haven't changed.  This is recommended
#   when using `options.streamlinejs`.
#
# e.g. `coffeeCoverage.register {path: 'abbr', basePath: "#{__dirname}/.." }`
#
module.exports = (options={}) ->
    # Clone options so we don't modify the original.
    options = _.defaults {}, options, {
        instrumentor: 'jscoverage'
        exclude: []
        basePath: null
        initFileStream: null
        initAll: false
        writeOnExit: null
        streamlinejs: false
        cachePath: null
    }

    # Add default options from the instrumentor.
    instrumentorClass = coffeeCoverage.INSTRUMENTORS[options.instrumentor]
    if !instrumentorClass
        throw new Error "Unknown instrumentor: #{options.instrumentor}.  " +
            "Valid options are #{Object.keys coffeeCoverage.INSTRUMENTORS}"
    if instrumentorClass.getDefaultOptions?
        defaults = instrumentorClass.getDefaultOptions()
        options = _.defaults options, defaults

    if options.basePath then options.basePath = path.resolve options.basePath
    if options.cachePath then options.cachePath = path.resolve options.cachePath

    compiledCache = new CompiledCache(options.basePath, options.cachePath)
    coverage = new coffeeCoverage.CoverageInstrumentor options
    module = require('module');

    if options.basePath and options.initAll
        # Recursively instrument everything in the base path to generate intialization data.
        options.initFileStream = new StringStream()
        coverage.instrumentDirectory options.basePath, null, options
        eval options.initFileStream.data

    instrumentFile = (fileName) ->
        content = fs.readFileSync fileName, 'utf8'
        instrumented = coverage.instrumentCoffee fileName, content
        return instrumented.init + instrumented.js

    replaceHandler = (extension) ->
        origCoffeeHandler = require.extensions[extension]
        require.extensions[extension] = (module, fileName) ->
            if excludeFile fileName, options
                return origCoffeeHandler.call this, module, fileName

            compiled = compiledCache.get fileName, -> instrumentFile(fileName)
            module._compile compiled, fileName

    replaceHandler ".coffee"
    replaceHandler ".litcoffee"
    replaceHandler ".coffee.md"

    if options.streamlinejs
        streamlineTransform = require 'streamline/lib/callbacks/transform'
        origStreamineCoffeeHandler = require.extensions["._coffee"]

        require.extensions["._coffee"] = (module, fileName) ->
            if excludeFile fileName, options
                return origStreamineCoffeeHandler.call this, module, fileName

            transformed = compiledCache.get fileName, ->
                compiled = instrumentFile fileName
                streamlineOptions = if _.isObject options.streamlinejs then options.streamlinejs else {}
                streamlineOptions = _.assign {}, streamlineOptions, {sourceName: fileName}
                transformed = streamlineTransform.transform(compiled, streamlineOptions)
                return transformed

            module._compile transformed, fileName

    if options.writeOnExit
        process.on 'exit', ->
            try
                dirName = path.dirname options.writeOnExit
                mkdirs dirName
                fs.writeFileSync options.writeOnExit, JSON.stringify(global[options.coverageVar])
            catch err
                console.error "Failed to write coverage data", err.stack ? err
