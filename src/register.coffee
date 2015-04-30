path           = require 'path'
path.sep       = path.sep || "/" # Assume "/" on older versions of node, where this is missing.
fs             = require 'fs'
_              = require 'lodash'

coffeeCoverage = require './coffeeCoverage'

class StringStream
    constructor: () ->
        @data = ""

    write: (data) ->
        @data += data

{mkdirs, excludeFile} = require './helpers'

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
# * `options.coverageVar` gives the name of the global variable to use to store
#   coverage data in. The default coverage variable depends on the `options.instrumentor` used.
# * `options.exclude` is an array of files and directories to ignore.  For example, ['/test'] would
#   ignore all files in the test folder.  Defaults to [].
# * `options.basePath` the root folder for your project.  If provided, then all excludes will be
#   evaluated relative to this base path. For example, if `options.exclude` is `['/a/b']`, and
#   `options.basePath` is "/Users/jwalton/myproject", then this will prevent
#   coffeeCoverage from traversing "/Users/jwalton/myproject/a/b".  Some instrumentor
#   implementations may strip the `basePath` for readability.
# * `options.initFileStream` is a stream to which all global initialization will be
#   written to via `initFileStream.write(data)`.
# * `options.initAll` - If true, then coffeeCoverage will recursively walk through all
#   subdirectories of `options.basePath` and gather line number information for all CoffeeScript
#   files found.  This way even files which are not `require`d at any point during your test will
#   still be instrumented and reported on.
# * `options.writeOnExit` - A file to write a JSON coverage file to on completion.  This will
#   stringify `options.coverageVar`.
# * `options.streamlinejs` - Enable experimental support for streamlinejs.  This option may
#   be removed in a future version of coffeeCoverage.
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
    }

    # Add default options from the instrumentor.
    instrumentorClass = coffeeCoverage.INSTRUMENTORS[options.instrumentor]
    if !instrumentorClass
        throw new Error "Unknown instrumentor: #{options.instrumentor}.  " +
            "Valid options are #{Object.keys coffeeCoverage.INSTRUMENTORS}"
    if instrumentorClass.getDefaultOptions?
        _.default options, instrumentorClass.getDefaultOptions()


    if options.basePath
        options.basePath = path.resolve options.basePath

        if options.initAll
            # Recursively instrument everything in the base path to
            # generate intialization data.
            options.initFileStream = new StringStream()

    coverage = new coffeeCoverage.CoverageInstrumentor options
    module = require('module');

    if options.basePath and options.initAll
        # Recursively instrument everything in the base path to generate intialization data.
        coverage.instrumentDirectory options.basePath, null
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
            module._compile instrumentFile(fileName), fileName
    replaceHandler ".coffee"
    replaceHandler ".litcoffee"
    replaceHandler ".coffee.md"

    if options.streamlinejs
        # TODO: This is pretty fragile, as we rely on some undocumented parts of streamline_js.
        # Would be better to do this via some programatic interface to streamline.  Need to make a
        # pull request.
        streamline_js = require.extensions["._js"]
        if streamline_js
            origStreamineCoffeeHandler = require.extensions["._coffee"]
            require.extensions["._coffee"] = (module, fileName) ->
                if excludeFile fileName, options
                    return origStreamineCoffeeHandler.call this, module, fileName

                compiled = instrumentFile fileName
                # TODO: Pass a sourcemap here?
                streamline_js module, fileName, compiled, null

    if options.writeOnExit
        process.on 'exit', ->
            try
                dirName = path.dirname options.writeOnExit
                mkdirs dirName
                fs.writeFileSync options.writeOnExit, JSON.stringify(global[options.coverageVar])
            catch err
                console.error "Failed to write coverage data", err.stack ? err
