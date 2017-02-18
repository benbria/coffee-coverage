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
# * `options.streamlinejs` - (deprecated) Enable support for streamlinejs < 1.x.  You can either pass `true`
#   here, or a set of options to pass on to
#   [transform](https://github.com/Sage/streamlinejs/blob/e10906d6cd/lib/callbacks/transform.md).
#
# * `options.postProcessors` - New way of compiling source after it has been coffee compiled and instrumented. Can apply
#   something like the streamline compiler. This puts all the power in the consumer's hands and allows for more
#   flexibility. Pass an array of objects of the form `{ext: '._coffee', fn: (compiled, fileName) -> }`. The `fn` will
#   be passed the coffee compiled/instrumented source, and the full path to the file.
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
        streamlinejs: false # deprecated
        postProcessors: []
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
    replaceHandler ".cjsx"
    replaceHandler ".litcoffee"
    replaceHandler ".coffee.md"

    # legacy option for `streamlinejs` < 1.x.
    # NOTE: deprecated. Use `options.postProcessors` instead.
    if options.streamlinejs
        console.warn "\noptions.streamlinejs is deprecated. Please use options.postProcessors\n"
        try
            streamlineTransform = require 'streamline/lib/callbacks/transform'
        catch err
            throw new Error "Could not load streamline transformer < 1.x"

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

    # setup any custom post processors
    if _.isArray(options.postProcessors) and options.postProcessors.length
        options.postProcessors.forEach (processorOpts={}) ->
            {ext, fn} = processorOpts
            if !(_.isString(ext) and _.isFunction(fn))
                return
            else if "._coffee" is ext and options.streamlinejs
                return

            originalHandler = require.extensions[ext]

            require.extensions[ext] = (module, fileName) ->
                if excludeFile fileName, options
                    return originalHandler.call this, module, fileName

                processed = compiledCache.get fileName, ->
                    compiled = instrumentFile fileName
                    fn(compiled, fileName)

                module._compile processed, fileName

    if options.writeOnExit
        process.on 'exit', ->
            try
                dirName = path.dirname options.writeOnExit
                mkdirs dirName
                fs.writeFileSync options.writeOnExit, JSON.stringify(global[options.coverageVar])
            catch err
                console.error "Failed to write coverage data", err.stack ? err
