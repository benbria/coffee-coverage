
#### CoffeeCoverage
#
# JSCoverage-style instrumentation for CoffeeScript files.
#
# By Jason Walton, Benbria
#

coffeeScript = require 'coffee-script'

events = require 'events'
fs = require 'fs'
util = require 'util'
path = require 'path'
_ = require 'lodash'
path.sep = path.sep || "/" # Assume "/" on older versions of node, where this is missing.

NodeWrapper = require './NodeWrapper'

INSTRUMENTORS = {
    jscoverage: require './instrumentors/JSCoverage'
    istanbul:   require './instrumentors/Istanbul'
}

exports.instrumentors = Object.keys(INSTRUMENTORS)

{mkdirs, stripLeadingDotOrSlash, statFile,
    getRelativeFilename, excludeFile, fixLocationData} = require './helpers'
{EXTENSIONS} = require './constants'

# Add 'version', 'author', and 'contributors' to our exports
pkginfo = require('pkginfo') module, 'version', 'author', 'contributors'

class CoverageError extends Error
    constructor: (@message) ->
        @name = "CoverageError"
        Error.call this
        Error.captureStackTrace this, arguments.callee

class StringStream
    constructor: () ->
        @data = ""

    write: (data) ->
        @data += data

# Default options.
factoryDefaults =
    coverageVar: '_$jscoverage'
    exclude: []
    recursive: true
    bare: false
    instrumentor: 'jscoverage'

# Register coffeeCoverage to automatically process '.coffee', '.litcoffee', '.coffee.md' and '._coffee' files.
#
# Note if you're using this in conjunction with
# [streamlinejs](https://github.com/Sage/streamlinejs), you *must* call this function
# after calling `streamline.register()`, otherwise by the time we get the source the
# file will already have been compiled.
#
# Parameters:
# * Any option from `CoverageInstrumentor.instrument()`, except `recursive`, `initFileStream`.
# * `options.path` should be one of:
#     * 'relative' - File names will be used as the file name in the instrumented sources.
#     * 'abbr' - an abbreviated file name will be constructed, with each parent in the path
#        replaced by the first character in its name.
#     * null - Path names will be omitted.  Only the base file name will be used.
# * `options.streamlinejs` - Enable experimental support for streamlinejs.  This option will
#   be removed in a future version of coffeeCoverage.
# * `options.initAll` - If true, then coffeeCoverage will recursively walk through all
#   subdirectories of `options.basePath` and gather line number information for all CoffeeScript files
#   found.  This way even files which are not `require`d at any point during your test will still
#   be instrumented and reported on.
#
# e.g. `coffeeCoverage.register {path: 'abbr', basePath: "#{__dirname}/.." }`
#
exports.register = (options) ->
    # Clone options so we don't modify the original.
    actualOptions = _.clone options

    if actualOptions.basePath
        actualOptions.basePath = path.resolve actualOptions.basePath

        if actualOptions.initAll
            # Recursively instrument everything in the base path to
            # generate intialization data.
            actualOptions.initFileStream = new StringStream()

    coverage = new exports.CoverageInstrumentor actualOptions
    module = require('module');

    if actualOptions.basePath and actualOptions.initAll
        # Recursively instrument everything in the base path to generate intialization data.
        coverage.instrumentDirectory actualOptions.basePath, null
        eval actualOptions.initFileStream.data

    instrumentFile = (fileName) ->
        content = fs.readFileSync fileName, 'utf8'
        coverageFileName = getRelativeFilename actualOptions.basePath, fileName
        instrumented = coverage.instrumentCoffee coverageFileName, content
        return instrumented.init + instrumented.js

    replaceHandler = (extension) ->
        origCoffeeHandler = require.extensions[extension]
        require.extensions[extension] = (module, fileName) ->
            if excludeFile fileName, actualOptions
                return origCoffeeHandler.call this, module, fileName
            module._compile instrumentFile(fileName), fileName
    replaceHandler ".coffee"
    replaceHandler ".litcoffee"
    replaceHandler ".coffee.md"

    if actualOptions.streamlinejs
        # TODO: This is pretty fragile, as we rely on some undocumented parts of streamline_js.
        # Would be better to do this via some programatic interface to streamline.  Need to make a
        # pull request.
        streamline_js = require.extensions["._js"]
        if streamline_js
            origStreamineCoffeeHandler = require.extensions["._coffee"]
            require.extensions["._coffee"] = (module, fileName) ->
                if excludeFile fileName, actualOptions
                    return origStreamineCoffeeHandler.call this, module, fileName

                compiled = instrumentFile fileName
                # TODO: Pass a sourcemap here?
                streamline_js module, fileName, compiled, null


#### CoverageInstrumentor
#
# Instruments .coffee files to provide code-coverage data.
class exports.CoverageInstrumentor extends events.EventEmitter

    #### Create a new CoverageInstrumentor
    #
    # For a list of available options see `@instrument`.
    #
    constructor: (options = {}) ->
        @defaultOptions = _.defaults {}, options, factoryDefaults

    # Write a string to a file.
    writeToFile = (outFile, content) ->
        fs.writeFileSync outFile, content

    # Some basic valication of source and out files.
    validateSrcDest = (source, out) ->
        sourceStat = statFile(source)
        outStat = if out then statFile(out) else null

        if !sourceStat
            throw new CoverageError("Source file #{source} does not exist.")

        if outStat
            if sourceStat.isFile() and outStat.isDirectory()
                throw new CoverageError("Refusing to overwrite directory #{out} with file.")

            if sourceStat.isDirectory() and outStat.isFile()
                throw new CoverageError("Refusing to overwrite file #{out} with directory.")

    # Generate a unique file name
    generateUniqueName = (usedNames, desiredName) ->
        answer = ""
        suffix = 1
        while true
            answer = desiredName + " (" + suffix + ")"
            if not (answer in usedNames) then break
            suffix++

        return answer

    #### Instrument a file or directory.
    #
    # This calls @instrumentFile or @instrumentDirectory, depending on whether "source" is
    # a file or directory respectively.
    #
    # * `options.coverageVar` gives the name of the global variable to use to store
    #   coverage data in. This defaults to '_$jscoverage' to be compatible with
    #   JSCoverage.
    # * `options.recursive` controls whether or not this will descend recursively into
    #    subdirectories. This defaults to true.
    # * `options.exclude` is an array of files to ignore.  instrumentDirectory will
    #   not instrument a file if it is in this list, nor will it recursively traverse
    #   into a directory if it is in this list.  This defaults to [].
    #   Note that this field is case sensitive!
    # * `options.basePath` if provided, then all excludes will be evaluated relative
    #   to this base path. For example, if `options.exclude` is `['a/b']`, and
    #   `options.basePath` is "/Users/jwalton/myproject", then this will prevent
    #   coffeeCoverage from traversing "/Users/jwalton/myproject/a/b". `basePath`
    #   will also be stripped from the front of any files when generating names.
    # * `options.initFileStream` is a stream to which all global initialization will be
    #   written to via `initFileStream.write(data)`.
    # * `options.log` should be a `{debug(), info(), warn(), error()}` object, where each is a function
    #   that takes multiple parameters and logs them (similar to `console.log()`.)
    # * `options.instrumentor` is the name of the instrumentor to use (see `INSTURMENTORS`.)
    #
    # Throws CoverageError if there is a problem with the `source` or `out` parameters.
    instrument: (source, out, options = {}) ->
        validateSrcDest source, out
        sourceStat = statFile source
        if sourceStat.isFile()
            return @instrumentFile source, out, options
        else if sourceStat.isDirectory()
            return @instrumentDirectory source, out, options
        else
            throw new CoverageError("Can't instrument #{source}.")

    # Return the output file name for a given input file name.
    #
    # e.g. `getOutputFileName('foo.coffee') # => 'foo.js'`
    #
    getOutputFileName: (fileName) ->
        return null if !fileName?
        outFile = fileName

        for coffee_extension, ext of EXTENSIONS
            if _.endsWith(fileName.toLowerCase(), coffee_extension)
                outFile = fileName[..-(coffee_extension.length+1)] + ext.js_extension
                break

        return outFile

    getEffectiveOptions = (options = {}, defaultOptions) -> _.defaults {}, options, defaultOptions

    #### Instrument a directory.
    #
    # This finds all .coffee files in the specified `sourceDirectory`, and writes instrumented
    # files into `outDirectory`.  `outDirectory` will be created if it does not already exist.
    #
    # For a list of available options see `@instrument`.
    #
    # Emits an "instrumentingDirectory" event before doing any work, with the names of the source
    # and out directories.  The directory names are guaranteed to end in path.sep.  Emits a
    # "skip" event for any files which are skipped because they are in the `options.exclude` list.
    #
    # Throws CoverageError if there is a problem with the `sourceDirectory` or `outDirectory`
    # parameters.
    #
    # Returns an object consisting of:
    #  - `lines` - the total number of instrumented lines.
    #
    instrumentDirectory: (sourceDirectory, outDirectory, options={}) ->
        # Turn the source directory into an absolute path
        sourceDirectory = path.resolve sourceDirectory

        @emit "instrumentingDirectory", sourceDirectory, outDirectory

        effectiveOptions = getEffectiveOptions options, @defaultOptions

        effectiveOptions.usedFileNames = effectiveOptions.usedFileNames || []
        effectiveOptions.basePath = if effectiveOptions.basePath
            path.resolve effectiveOptions.basePath
        else
            sourceDirectory

        answer = {lines: 0}

        validateSrcDest sourceDirectory, outDirectory

        # Make sure the directory names end in "/"
        if !_.endsWith sourceDirectory, path.sep
            sourceDirectory += path.sep
        sourceDirectoryMode = (statFile sourceDirectory).mode

        if outDirectory
            if !_.endsWith outDirectory, path.sep
                outDirectory += path.sep

            # Check to see if the output directory exists
            outDirectoryStat = statFile outDirectory
            outputDirectoryExists = !!outDirectoryStat


        # Instrument every file in the directory
        for file in fs.readdirSync(sourceDirectory)
            sourceFile = sourceDirectory + file
            if excludeFile sourceFile, effectiveOptions
                @emit "skip", sourceDirectory + file
                continue

            outFile = if outDirectory then outDirectory + file else null

            sourceStat = statFile sourceFile

            if effectiveOptions.recursive and sourceStat.isDirectory()
                inst = @instrumentDirectory sourceFile, outFile, effectiveOptions
                answer.lines += inst.lines
            else
                processed = false
                for coffee_extension of EXTENSIONS
                    # TODO: Make this work for streamline files.
                    if coffee_extension is '._coffee' then continue

                    if _.endsWith(file.toLowerCase(), coffee_extension) and sourceStat.isFile()
                        # lazy-create the output directory.
                        if outDirectory? and !outputDirectoryExists
                            mkdirs outDirectory, sourceDirectoryMode
                            outputDirectoryExists = true

                        # Replace the ".(lit)coffee(.md)" extension with a ".js" extension
                        outFile = @getOutputFileName outFile
                        instrumentOptions = _.assign {}, effectiveOptions, {
                            fileName: getRelativeFilename options.basePath, sourceFile
                        }
                        inst = @instrumentFile sourceFile, outFile, instrumentOptions
                        answer.lines += inst.lines
                        processed = true
                        break

        return answer


    #### Instrument a .coffee file.
    #
    # Same as `@instrumentCoffee` but takes a file name instead of file data.
    #
    # Emits an "instrumentingFile" event with the name of the input and output file.
    #
    # * `outFile` is optional; if present then the compiled JavaScript will be written out to this
    #   file.
    # * `options.fileName` is the fileName to use in the generated instrumentation.
    #
    # For other options, see `@instrumentCoffee` and `@instrument`.
    #
    # Throws CoverageError if there is a problem with the `sourceFile` or `outFile` parameters.
    instrumentFile: (sourceFile, outFile=null, options={}) ->
        @emit "instrumentingFile", sourceFile, outFile

        effectiveOptions = getEffectiveOptions options, @defaultOptions

        validateSrcDest sourceFile, outFile

        data = fs.readFileSync sourceFile, 'utf8'
        answer = @instrumentCoffee (effectiveOptions.fileName or sourceFile), data, effectiveOptions

        if outFile
            writeToFile outFile, (answer.init + answer.js)

        return answer

    #### Instrument a .coffee file.
    #
    # Parameters:
    #
    # * `fileData` is the contents of the coffee file.
    #
    # * `options.path` should be one of:
    #     * 'relative' - `fileName` will be used as the file name in the instrumented sources.
    #     * 'abbr' - an abbreviated file name will be constructed, with each parent in the path
    #        replaced by the first character in its name.
    #     * null - Path names will be omitted.  Only the base file name will be used.
    #
    # * If `options.usedFileNames` is present, it must be an array.  This method will add the
    #   name of the file to usedFileNames.  If the name of the file is already in usedFileNames
    #   then this method will generate a unique name.
    #
    # * If `options.initFileStream` is present, then all global initialization will be written
    #   to `initFileStream.write()`, in addition to being returned.
    #
    # Returns an object consisting of:
    # * `init` - the intialization JavaScript code.
    # * `js` - the compiled JavaScript, instrumented to collect coverage data.
    # * `lines` - the total number of instrumented lines.
    #
    instrumentCoffee: (fileName, fileData, options={}) ->
        effectiveOptions = getEffectiveOptions options, @defaultOptions

        effectiveOptions.log?.info "Instrumenting #{fileName}"

        instrumentorConstructor = INSTRUMENTORS[effectiveOptions.instrumentor]
        instrumentor = new instrumentorConstructor(fileName, effectiveOptions)

        result = exports._runInstrumentor instrumentor, fileName, fileData, effectiveOptions

        effectiveOptions.initFileStream?.write result.init

        return result

# Runs an instrumentor on some source code.
#
# * `instrumentor` an instance of an instrumentor class to run on.
# * `fileName` the name of the source file.
# * `source` a string containing the sourcecode the instrument.
# * `options.bare` true if we should compile bare coffee-script (no enclosing function).
# * `options.log` log object.
#
exports._runInstrumentor = (instrumentor, fileName, source, options={}) ->
    # Compile coffee to nodes.
    try
        options.log?.debug "Instrumenting #{fileName}"
        coffeeOptions = {
            bare: options.bare ? false
            literate: /\.(litcoffee|coffee\.md)$/.test(fileName)
        }

        tokens = coffeeScript.tokens source, coffeeOptions

        # collect referenced variables
        coffeeOptions.referencedVars = (token[1] for token in tokens when token.variable)

        # convert tokens to ast
        ast = coffeeScript.nodes(tokens)
    catch err
        throw new CoverageError("Could not parse #{fileName}: #{err.stack}")

    instrumentTree = (nodeWrapper) =>
        # Ignore code that we generated.
        return if nodeWrapper.node.coffeeCoverage?.generated

        indent = ("  " for i in [0...nodeWrapper.depth]).join ''

        if nodeWrapper.node.coffeeCoverage?.visited
            throw new Error "Revisiting node #{nodeWrapper.toString()}"

        options.log?.debug "#{indent}Examining #{nodeWrapper.toString()}"

        if nodeWrapper.isStatement
            instrumentor["visitStatement"]?(nodeWrapper)

        # Call block-specific visitor function.
        instrumentor["visit#{nodeWrapper.type}"]?(nodeWrapper)

        # Recurse into child nodes
        nodeWrapper.forEachChild (child) ->
            options.log?.debug "#{indent}Recursing into #{child.toString()}"
            instrumentTree(child)

            child.node.coffeeCoverage ?= {}
            child.node.coffeeCoverage.visited = true

    instrumentTree(new NodeWrapper ast)

    init = instrumentor.getInitString({source})

    # Compile the instrumented CoffeeScript and write it to the JS file.
    try
        js = ast.compile coffeeOptions
    catch err
        throw new CoverageError("Could not compile #{fileName} after annotating: #{err.stack}")

    answer = {
        init: init
        js: js
        lines: instrumentor.getInstrumentedLineCount()
    }

    return answer
