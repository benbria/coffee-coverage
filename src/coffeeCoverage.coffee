
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
path.sep = path.sep || "/" # Assume "/" on older versions of node, where this is missing.

{startsWith, endsWith, defaults, abbreviatedPath, mkdirs, stripLeadingDotOrSlash, statFile} = require './helpers'

# Add 'version', 'author', and 'contributors' to our exports
pkginfo = require('pkginfo') module, 'version', 'author', 'contributors'

debug = -> # Do nothing.

EXTENSIONS = {
    ".coffee":  {js_extension: ".js"}
    ".litcoffee":  {js_extension: ".js"}
    ".coffee.md":  {js_extension: ".js"}
    "._coffee": {js_extension: "._js"}
}

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
defaultOptions =
    coverageVar: '_$jscoverage'
    exclude: []
    recursive: true
    bare: false

# Return the relative path for the file from the basePath.  Returns file name
# if the file is not relative to basePath.
getRelativeFilename = (basePath, fileName) ->
    relativeFileName = path.resolve fileName
    if basePath? and startsWith(relativeFileName, basePath)
        relativeFileName = path.relative basePath, fileName
    return relativeFileName


# Register coffeeCoverage to automatically process '.coffee', '.litcoffee', '.coffee.md' and '._coffee' files.
#
# Note if you're using this in conjunction with
# [streamlinejs](https://github.com/Sage/streamlinejs), you *must* call this function
# after calling `streamline.register()`, otherwise by the time we get the source the
# file will already have been compiled.
#
# Parameters:
# * `options.coverageVar` gives the name of the global variable to use to store coverage data in.
#   This defaults to '_$jscoverage' to be compatible with JSCoverage.
# * `options.basePath` is the root folder of your project.  This path will be stripped from
#   file names.
# * `options.path` should be one of:
#     * 'relative' - File names will be used as the file name in the instrumented sources.
#     * 'abbr' - an abbreviated file name will be constructed, with each parent in the path
#        replaced by the first character in its name.
#     * null - Path names will be omitted.  Only the base file name will be used.
# * `options.exclude` is an array of files to ignore.  instrumentDirectory will not instrument
#   a file if it is in this list, nor will it recursively traverse into a directory if it is
#   in this list.  This defaults to [] if not explicitly passed.  Note that this option
#   will only work if `options.basePath` is provided.
# * `options.streamlinejs` - Enable experimental support for streamlinejs.  This option will
#   be removed in a future version of coffeeCoverage.
# * `options.initAll` - If true, then coffeeCoverage will recursively walk through all
#   subdirectories of `options.basePath` and gather line number information for all CoffeeScript files
#   found.  This way even files which are not `require`d at any point during your test will still
#   br instrumented and reported on.
#
# e.g. `coffeeCoverage.register {path: 'abbr', basePath: "#{__dirname}/.." }`
#
exports.register = (options) ->
    coverage = new exports.CoverageInstrumentor options
    module = require('module');

    if options.basePath
        basePath = path.resolve options.basePath

        if options.initAll
            # Recursively instrument everything in the base path to generate intialization data.
            initStream = new StringStream()
            coverage.instrumentDirectory options.basePath, null, {
                exclude: options.exclude
                recursive: true
                initFileStream: initStream
            }
            eval initStream.data

    # Return true if we should exclude a file
    excludeFile = (fileName) ->
        exclude = options.exclude or []

        excluded = false
        if basePath
            relativeFilename = getRelativeFilename basePath, fileName
            if relativeFilename == fileName
                # Only instrument files that are inside the project.
                excluded = true

            components = relativeFilename.split path.sep
            for component in components
                if component in exclude
                    excluded = true

            if !excluded
                for excludePath in exclude
                    if startsWith "/#{relativeFilename}", excludePath
                        excluded = true

        if !excluded and (not path.extname(fileName) in Object.keys(EXTENSIONS))
            excluded = true


        if !excluded
            for excludePath in exclude
                if startsWith fileName, excludePath
                    excluded = true

        return excluded

    instrumentFile = (fileName) ->
        content = fs.readFileSync fileName, 'utf8'
        coverageFileName = getRelativeFilename basePath, fileName
        instrumented = coverage.instrumentCoffee coverageFileName, content, options
        return instrumented.init + instrumented.js

    replaceHandler = (extension) ->
        origCoffeeHandler = require.extensions[extension]
        require.extensions[extension] = (module, fileName) ->
            if excludeFile fileName
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
                if excludeFile fileName
                    return origStreamineCoffeeHandler.call this, module, fileName

                compiled = instrumentFile(fileName)
                # TODO: Pass a sourcemap here?
                streamline_js module, fileName, compiled, null


#### CoverageInstrumentor
#
# Instruments .coffee files to provide code-coverage data.
class exports.CoverageInstrumentor extends events.EventEmitter

    #### Create a new CoverageInstrumentor
    #
    # `options.coverageVar` gives the name of the global variable to use to store coverage data in.
    # This defaults to '_$jscoverage' to be compatible with JSCoverage.
    #
    # Any option which can be passed to instrumentDirectory may also be passed here, and will
    # serve as a default value.
    #
    constructor: (options = {}) ->
        @options = defaults options, defaultOptions

    # Takes in a string, and returns a quoted string with any \s and "s in the string escaped.
    toQuotedString = (string) ->
        answer = string.replace /\\/g, '\\\\'
        return '"' + (answer.replace /"/g, '\\\"') + '"'

    # Takes the contents of a file and returns an array of lines.
    # `fileData` is a string containing an entire file.
    fileToLines = (fileData) ->
        dataWithFixedLfs = fileData.replace(/\r\n/g, '\n').replace(/\r/g, '\n')
        return dataWithFixedLfs.split("\n")

    # Return the type of an AST node.
    nodeType = (node) ->
        return node?.constructor?.name or null

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
    # Throws CoverageError if there is a problem with the `source` or `out` parameters.
    instrument: (source, out, options) ->
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
            if endsWith(fileName.toLowerCase(), coffee_extension)
                outFile = fileName[..-(coffee_extension.length+1)] + ext.js_extension
                break

        return outFile


    #### Instrument a directory.
    #
    # This finds all .coffee files in the specified `sourceDirectory`, and writes instrumented
    # files into `outDirectory`.  `outDirectory` will be created if it does not already exist.
    #
    # * `options.recursive` controls whether or not this will descend recursively into
    #    subdirectories.  This defaults to true if not explicitly passed or specified in the
    #    constructor.
    # * `options.exclude` is an array of files to ignore.  instrumentDirectory will not instrument
    #   a file if it is in this list, nor will it recursively traverse into a directory if it is
    #   in this list.  This defaults to [] if not explicitly passed or specified in the
    #   constructor.  Note that this field is case sensitive!
    # * `options.basePath` if provided, then all excludes will be evaluated relative to this
    #   base path.  For example, if `options.exclude` is `['a/b']`, and `options.basePath` is
    #   "/Users/jwalton/myproject", then this will prevent coffeeCoverage from traversing
    #   "/Users/jwalton/myproject/a/b".  `basePath` will also be stripped from the front
    #   of any files when generating names.
    # * `options.initFileStream` is a stream to which all global initialization will be
    #   written to via `initFileStream.write(data)`.
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
    instrumentDirectory: (sourceDirectory, outDirectory, options = {}) ->
        # Turn the source directory into an absolute path
        sourceDirectory = path.resolve sourceDirectory

        @emit "instrumentingDirectory", sourceDirectory, outDirectory

        options = Object.create options
        options.usedFileNames = options.usedFileNames || []
        options.basePath = if options.basePath
            path.resolve options.basePath
        else
            sourceDirectory

        answer = {lines: 0}

        options = defaults options, @options

        validateSrcDest sourceDirectory, outDirectory

        # Make sure the directory names end in "/"
        if !endsWith sourceDirectory, path.sep
            sourceDirectory += path.sep
        sourceDirectoryMode = (statFile sourceDirectory).mode

        if outDirectory
            if !endsWith outDirectory, path.sep
                outDirectory += path.sep

            # Check to see if the output directory exists
            outDirectoryStat = statFile outDirectory
            outputDirectoryExists = !!outDirectoryStat


        # Instrument every file in the directory
        for file in fs.readdirSync(sourceDirectory)
            skip = false
            if file in options.exclude
                skip = true

            sourceFile = sourceDirectory + file
            relativePath = getRelativeFilename options.basePath, sourceFile
            if relativePath != sourceFile then for exclude in options.exclude
                if startsWith relativePath, exclude
                    skip = true

            if skip
                @emit "skip", sourceDirectory + file
                continue

            outFile = if outDirectory then outDirectory + file else null

            sourceStat = statFile sourceFile

            if options.recursive and sourceStat.isDirectory()
                inst = @instrumentDirectory sourceFile, outFile, options
                answer.lines += inst.lines
            else
                processed = false
                for coffee_extension of EXTENSIONS
                    # TODO: Make this work for streamline files.
                    if coffee_extension is '._coffee' then continue

                    if endsWith(file.toLowerCase(), coffee_extension) and sourceStat.isFile()
                        # lazy-create the output directory.
                        if outDirectory? and !outputDirectoryExists
                            mkdirs outDirectory, sourceDirectoryMode
                            outputDirectoryExists = true

                        # Replace the ".(lit)coffee(.md)" extension with a ".js" extension
                        outFile = @getOutputFileName outFile
                        instrumentOptions = Object.create options
                        instrumentOptions.fileName = relativePath
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
    # For other options, see `@instrumentCoffee`.
    #
    # Throws CoverageError if there is a problem with the `sourceFile` or `outFile` parameters.
    instrumentFile: (sourceFile, outFile=null, options={}) ->
        @emit "instrumentingFile", sourceFile, outFile

        validateSrcDest sourceFile, outFile

        data = fs.readFileSync sourceFile, 'utf8'
        answer = @instrumentCoffee (options.fileName or sourceFile), data, options

        if outFile
            writeToFile outFile, (answer.init + answer.js)

        return answer

    # Fix up location data for each instrumentedLine.  Make these all 0-length,
    # so we don't have to rewrite the location data for all the non-generated
    # nodes in the tree.
    fixLocationData = (instrumentedLine, line) ->
        doIt = (node) ->
            node.locationData =
                first_line: line - 1 # -1 because `line` is 1-based
                first_column: 0
                last_line: line - 1
                last_column: 0
        doIt instrumentedLine
        instrumentedLine.eachChild doIt


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
    instrumentCoffee: (fileName, fileData, options = {}) ->
        origFileName = fileName
        literate = /\.(litcoffee|coffee\.md)$/.test(fileName)

        switch options.path
            when 'relative' then fileName = stripLeadingDotOrSlash fileName
            when 'abbr' then fileName = abbreviatedPath stripLeadingDotOrSlash fileName
            else fileName = path.basename fileName

        # Generate a unique fileName if required.
        if options.usedfileNames
            if fileName in options.usedfileNames
                fileName = generateUniqueName options.usedfileNames, fileName
            options.usedfileNames.push fileName

        quotedFileName = toQuotedString fileName

        try
            ast = coffeeScript.nodes(fileData, {literate: literate})
        catch err
            throw new CoverageError("Could not parse #{fileName}: #{err.stack}")

        # Add coverage instrumentation nodes throughout the tree.
        instrumentedLines = []
        instrumentTree = (node, parent=null, depth=0) =>
            debug "Examining  l:#{node.locationData.first_line + 1} d:#{depth} #{nodeType(node)}"

            if (nodeType(node) != "Block") or node.coffeeCoverageDoNotInstrument
                if nodeType(node) is "If" and node.isChain
                    # Chaining is where coffee compiles something into `... else if ...`
                    # instead of '... else {if ...}`.  Chaining produces nicer looking coder
                    # with fewer indents, but it also produces code that's harder to instrument,
                    # so we turn it off.
                    #

                    debug "  Disabling chaining for if statement"
                    node.isChain = false

                    # An alternative to to disable instrumentation on the else node.
                    #node.elseBody.coffeeCoverageDoNotInstrument = true

                # Recurse into child nodes
                node.eachChild (child) => instrumentTree(child, node, depth + 1)

            else
                # If this is a block, then instrument all the lines in the block.
                children = node.expressions
                childIndex = 0
                while childIndex < children.length
                    expression = children[childIndex]
                    line = expression.locationData.first_line + 1

                    doAnnotation = true

                    if nodeType(expression) is "Comment"
                        # Don't bother to instrument the comment.
                        doAnnotation = false

                    if line in instrumentedLines
                        # Never instrument the same line twice.  This can happen in a situation like:
                        #
                        #     if x then console.log "foo"
                        #
                        # Here the "if" statement can be instrumented, but we could also instrument the
                        # "console.log" statement on the same line.
                        #
                        # Note that we also run into a weird situation here:
                        #
                        #     x = if y then {name: "foo"} \
                        #              else {name: "bar"}
                        #
                        # Because here we're going to instrument the inside of the "else" block,
                        # but not the inside of the "if" block, which is OK, but a bit weird.
                        debug "Skipping   l:#{line} d:#{depth + 1} #{nodeType(expression)}"
                        doAnnotation = false

                    if doAnnotation
                        debug "Annotating l:#{line} d:#{depth + 1} #{nodeType(expression)}"

                        instrumentedLines.push line

                        instrumentedLine = coffeeScript.nodes(
                            "#{@options.coverageVar}[#{quotedFileName}][#{line}]++")

                        fixLocationData instrumentedLine, line

                        # Add the new nodes immediately before the statement we're instrumenting.
                        children.splice(childIndex, 0, instrumentedLine);
                        childIndex++

                    # Annotate child expressions here, so we don't waste time instrumenting
                    # our instrumentedLines.
                    instrumentTree(expression, node, depth + 1)
                    childIndex++

        instrumentTree(ast)

        # Write out top-level initalization
        init = """
            if (typeof #{@options.coverageVar} === 'undefined') #{@options.coverageVar} = {};
            if ((typeof global !== 'undefined') && (typeof global.#{@options.coverageVar} === 'undefined')) {
                global.#{@options.coverageVar} = #{@options.coverageVar}
            } else if ((typeof window !== 'undefined') && (typeof window.#{@options.coverageVar} === 'undefined')) {
                window.#{@options.coverageVar} = #{@options.coverageVar}
            }
            if (! #{@options.coverageVar}[#{quotedFileName}]) {
                #{@options.coverageVar}[#{quotedFileName}] = [];\n"""

        for lineNumber in instrumentedLines
            init += "    #{@options.coverageVar}[#{quotedFileName}][#{lineNumber}] = 0;\n"

        init += "}\n\n"

        # Write the original source code into the ".source" array.
        init += "#{@options.coverageVar}[#{quotedFileName}].source = ["
        fileToInstrumentLines = fileToLines fileData
        for line, index in fileToInstrumentLines
            if !!index then init += ", "
            init += toQuotedString(line)
        init += "];\n\n"

        # Compile the instrumented CoffeeScript and write it to the JS file.
        try
            js = ast.compile {bare: options.bare, literate: literate}
        catch err
            throw new CoverageError("Could not compile #{fileName} after annotating: #{err.stack}")

        options.initFileStream?.write init

        answer = {
            init: init
            js: js
            lines: instrumentedLines.length
        }

        return answer
