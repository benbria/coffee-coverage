
#### CoffeeCoverage
#
# JSCoverage-style instrumentation for CoffeeScript files.
#
# By Jason Walton, Benbria
#

assert       = require 'assert'
events       = require 'events'
fs           = require 'fs'
util         = require 'util'
path         = require 'path'
coffeeScript = require 'coffee-script'
_            = require 'lodash'

NodeWrapper                     = require './NodeWrapper'
{mkdirs, statFile, excludeFile} = require './utils/helpers'
{EXTENSIONS}                    = require './constants'
SkipVisitor                     = require './SkipVisitor'

exports.INSTRUMENTORS = INSTRUMENTORS = {
    jscoverage: require './instrumentors/JSCoverage'
    istanbul:   require './instrumentors/Istanbul'
}

class CoverageError extends Error
    constructor: (@message) ->
        @name = "CoverageError"
        Error.call this
        Error.captureStackTrace this, arguments.callee

# Default options.
factoryDefaults =
    exclude: []
    recursive: true
    bare: false
    instrumentor: 'jscoverage'

exports.getInstrumentorClass = getInstrumentorClass = (instrumentorName) ->
    instrumentor = INSTRUMENTORS[instrumentorName]
    if !instrumentor
        throw new Error "Invalid instrumentor #{instrumentorName}. Valid options are: #{Object.keys(INSTRUMENTORS).join ', '}"
    return instrumentor

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
        _.defaults @defaultOptions, getInstrumentorClass(@defaultOptions.instrumentor).getDefaultOptions()

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
    #   All options passed in will be passed along to the instrumentor implementation, so
    #   instrumentor-specific options may be added to `options` as well.
    #
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
                        inst = @instrumentFile sourceFile, outFile, effectiveOptions
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
        answer = @instrumentCoffee path.resolve(sourceFile), data, effectiveOptions

        if outFile
            writeToFile outFile, (answer.init + answer.js)

        return answer

    #### Instrument a .coffee file.
    #
    # Parameters:
    #
    # * `fileName` is the name of the file.  This should be an absolute path.
    #
    # * `source` is the contents of the coffee file.
    #
    # * `options.fileName` - if rpresent, this will be the filename passed to the instrumentor.
    #   Otherwise the absolute path will be passed.
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
    instrumentCoffee: (fileName, source, options={}) ->
        effectiveOptions = getEffectiveOptions options, @defaultOptions

        effectiveOptions.log?.info "Instrumenting #{fileName}"

        instrumentorConstructor = getInstrumentorClass effectiveOptions.instrumentor
        instrumentor = new instrumentorConstructor(fileName, source, effectiveOptions)

        result = exports._runInstrumentor instrumentor, fileName, source, effectiveOptions

        effectiveOptions.initFileStream?.write result.init

        return result

# Runs an instrumentor on some source code.
#
# * `instrumentor` an instance of an instrumentor class to run on.
# * `fileName` the absolute path of the source file.
# * `source` a string containing the sourcecode the instrument.
# * `options.bare` true if we should compile bare coffee-script (no enclosing function).
# * `options.log` log object.
#
exports._runInstrumentor = (instrumentor, fileName, source, options={}) ->
    assert instrumentor, "instrumentor"

    # Compile coffee to nodes.
    try
        options.log?.debug? "Instrumenting #{fileName}"
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

    runVisitor = (visitor, nodeWrapper) =>
        # Ignore code that we generated.
        return if nodeWrapper.node.coffeeCoverage?.generated

        if options.log?.debug?
            indent = ("  " for i in [0...nodeWrapper.depth]).join ''
            options.log.debug "#{indent}Examining #{nodeWrapper.toString()}"

        if nodeWrapper.isStatement
            visitor["visitStatement"]?(nodeWrapper)

        # Call block-specific visitor function.
        visitor["visit#{nodeWrapper.type}"]?(nodeWrapper)

        # Recurse into child nodes
        nodeWrapper.forEachChild (child) ->
            runVisitor(visitor, child)

    wrappedAST = new NodeWrapper ast

    runVisitor(new SkipVisitor(fileName), wrappedAST)
    runVisitor(instrumentor, wrappedAST)

    init = instrumentor.getInitString()

    # Compile the instrumented CoffeeScript and write it to the JS file.
    try
        js = ast.compile coffeeOptions
    catch err
        ### !pragma coverage-skip-block ###
        throw new CoverageError("Could not compile #{fileName} after instrumenting: #{err.stack}")

    answer = {
        init: init
        js: js
        lines: instrumentor.getInstrumentedLineCount()
    }

    return answer
