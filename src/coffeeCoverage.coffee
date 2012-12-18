
#### CoffeeCoverage
#
# JSCoverage-style instrumentation for CoffeeScript files.
#
# By Jason Walton, Benbria
#

# Temporarily use our own private version of coffee-script.
coffeeScript = require '../dep/coffee-script/coffee-script'

pkginfo = require('pkginfo') module, 'version', 'author', 'contributors'

events = require 'events'
fs = require 'fs'
util = require 'util'
path = require 'path'
path.sep = path.sep || "/" # Assume "/" on older versions of node, where this is missing.

{endsWith, defaults, abbreviatedPath, mkdirs, stripLeadingDot, statFile} = require './helpers'


COFFEE_EXTENSION = ".coffee"
JS_EXTENSION     = ".js"

class CoverageError extends Error
    constructor: (@message) ->
        @name = "CoverageError"
        Error.call this
        Error.captureStackTrace this, arguments.callee

# Default options.
defaultOptions =
    coverageVar: '_$jscoverage'
    exclude: []
    recursive: true

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
        return node.constructor.name

    # Write a string to a file.
    writeToFile = (outFile, contect) ->
        outStream = fs.createWriteStream outFile
        outStream.end(contect)

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

    # Generate a unique filename
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

    #### Instrument a directory.
    #
    # This finds all .coffee files in the specified `sourceDirectory`, and writes instrumented
    # files into `outDirectory`.  `outDirectory` will be created if it does not already exist.
    #
    #  -  `options.recursive` controls whether or not this will descend recursively into
    #     subdirectories.  This defaults to true if not explicitly passed or specified in the
    #     constructor.
    #  - `options.exclude` is an array of files to ignore.  instrumentDirectory will not instrument
    #    a file if it is in this list, nor will it recursively traverse into a directory if it is
    #    in this list.  This defaults to [] if not explicitly passed or specified in the
    #    constructor.  Note that this field is case sensitive!
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
        @emit "instrumentingDirectory", sourceDirectory, outDirectory

        options.usedFileNames = options.usedFileNames || []

        answer =
            lines: 0

        options = defaults options, @options

        validateSrcDest sourceDirectory, outDirectory

        # Make sure the directory names end in "/"
        if !endsWith sourceDirectory, path.sep
            sourceDirectory += path.sep

        if !endsWith outDirectory, path.sep
            outDirectory += path.sep

        # Check to see if the output directory exists
        outDirectoryStat = statFile outDirectory
        outputDirectoryExists = !!outDirectoryStat
        sourceDirectoryMode = (statFile sourceDirectory).mode


        # Instrument every file in the directory
        for file in fs.readdirSync(sourceDirectory)
            if file in options.exclude
                @emit "skip", sourceDirectory + file
                continue

            sourceFile = sourceDirectory + file
            outFile = outDirectory + file

            sourceStat = statFile sourceFile

            if endsWith(file.toLowerCase(), COFFEE_EXTENSION) and sourceStat.isFile()
                # lazy-create the output directory.
                if !outputDirectoryExists
                    mkdirs outDirectory, sourceDirectoryMode
                    outputDirectoryExists = true

                # Replace the ".coffee" extension with a ".js" extension
                outFile = outFile[..-(COFFEE_EXTENSION.length+1)] + JS_EXTENSION
                inst = @instrumentFile sourceFile, outFile, options
                answer.lines += inst.lines

            else if options.recursive and sourceStat.isDirectory()
                inst = @instrumentDirectory sourceFile, outFile, options
                answer.lines += inst.lines

        return answer


    #### Instrument a .coffee file.
    #
    # Same as `@instrumentCoffee` but takes a file name instead of file data.
    #
    # Emits an "instrumentingFile" event with the name of the input and output file.
    #
    #  - `outFile` is optional; if present then the compiled JavaScript will be written out to this
    #    file.
    #  - If `options.path` is 'relative', then `sourceFile` will be used as the file name in
    #    the instrumented sources.  If this value is 'abbr' then an abbreviated filename will be
    #    constructed, with each parent in the path being replaced by the first character in its
    #    name.  If this option has any other value, path names will be omitted.
    #
    #  - If `options.usedFileNames` is present, it must be an array.  This method will add the
    #    name of the file to usedFileNames.  If the name of the file is already in usedFileNames
    #    then this method will generate a unique name.
    #
    #  - If `options.initFileStream` is present, then all global initialization will be written
    #    to `initFileStream.write()`, in addition to each instrumented source file.
    #
    # Throws CoverageError if there is a problem with the `sourceFile` or `outFile` parameters.
    instrumentFile: (sourceFile, outFile, options) ->
        @emit "instrumentingFile", sourceFile, outFile

        validateSrcDest sourceFile, outFile

        switch options.path
            when 'relative' then filename = stripLeadingDot sourceFile
            when 'abbr' then filename = abbreviatedPath stripLeadingDot sourceFile
            else filename = path.basename sourceFile

        # Generate a unique filename if required.
        if options.usedFileNames and filename in options.usedFileNames
            filename = generateUniqueName options.usedFileNames, filename

        if options.usedFileNames then options.usedFileNames.push filename


        data = fs.readFileSync sourceFile, 'utf8'
        answer = @instrumentCoffee filename, data

        options.initFileStream?.write answer.init

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
    # `fileData` is the contents of the coffee file.
    #
    # Returns an object consisting of:
    #  - `init` - the intialization JavaScript code.
    #  - `js` - the compiled JavaScript, instrumented to collect coverage data.
    #  - `lines` - the total number of instrumented lines.
    #
    instrumentCoffee: (fileName, fileData) ->
        options = @options

        quotedFilename = toQuotedString fileName

        ast = coffeeScript.nodes(fileData)

        # Add coverage instrumentation nodes throughout the tree.
        instrumentedLines = []
        instrumentTree = (node) ->
            # If this is a block, then instrument all the lines in the block.
            if nodeType(node) != "Block"
                node.eachChild (child) -> instrumentTree(child)

            else
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
                        doAnnotation = false

                    if doAnnotation
                        instrumentedLines.push line

                        instrumentedLine = coffeeScript.nodes(
                            "#{options.coverageVar}[#{quotedFilename}][#{line}]++")

                        fixLocationData instrumentedLine, line

                        # Add the new nodes immediately before the statement we're instrumenting.
                        children.splice(childIndex, 0, instrumentedLine);
                        childIndex++

                    # Annotate child expressions here, so we don't waste time instrumenting
                    # our instrumentedLines.
                    instrumentTree(expression)
                    childIndex++

        instrumentTree(ast)

        # Write out top-level initalization
        init = """
            if (typeof #{options.coverageVar} === 'undefined') #{options.coverageVar} = {};
            if ((typeof global !== 'undefined') && (typeof global.#{options.coverageVar} === 'undefined')) {
                global.#{options.coverageVar} = #{options.coverageVar}
            } else if ((typeof window !== 'undefined') && (typeof window.#{options.coverageVar} === 'undefined')) {
                window.#{options.coverageVar} = #{options.coverageVar}
            }
            if (! #{options.coverageVar}[#{quotedFilename}]) {
                #{options.coverageVar}[#{quotedFilename}] = [];\n"""

        for lineNumber in instrumentedLines
            init += "    #{options.coverageVar}[#{quotedFilename}][#{lineNumber}] = 0;\n"

        init += "}\n\n"

        # Write the original source code into the ".source" array.
        init += "#{options.coverageVar}[#{quotedFilename}].source = ["
        fileToInstrumentLines = fileToLines fileData
        for line, index in fileToInstrumentLines
            if !!index then init += ", "
            init += toQuotedString(line)
        init += "];\n\n"

        # Compile the instrumented CoffeeScript and write it to the JS file.
        js = ast.compile {}

        return {
            init: init
            js: js
            lines: instrumentedLines.length
        }
