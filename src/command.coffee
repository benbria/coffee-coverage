#!/usr/bin/env coffee

# Implements functionality for the CLI command

fs = require 'fs'
path = require 'path'
path.sep = path.sep || "/" # Assume "/" on older versions of node, where this is missing.

{CoverageInstrumentor, version} = require './coffeeCoverage'
{stripLeadingDotOrSlash, mkdirs} = require './helpers'

printHelp = () ->
    console.log usageString

parseArgs = (args) ->
    ArgumentParser = require('argparse').ArgumentParser
    parser = new ArgumentParser
        version: version
        addHelp: true
        description: """
            Compiles CoffeeScript into JavaScript with JSCoverage-compatible instrumentation for code coverage.
            """

    parser.addArgument [ '--verbose' ],
        help: "Verbose output"
        nargs: 0

    parser.addArgument [ '-b', '--bare' ],
        help: "compile without a top-level function wrapper"
        metavar: "bare"
        nargs: 0

    coverageVarDefault = '_$jscoverage'
    parser.addArgument [ '-c', '--coverageVar' ],
        help: """Set the name to use in the instrumented code for the coverage variable.  Defaults to
              '#{coverageVarDefault}'."""
        metavar: "name"
        defaultValue: coverageVarDefault

    excludeDefault = "node_modules,.git"
    parser.addArgument [ '-e', '--exclude' ],
        help: """Comma delimited set of file names to exclude.  Any file or directory which is in
              this list will be ignored.  Note that this field is case sensitive.  Defaults to
              '#{excludeDefault}'."""
        metavar: "filenames"
        defaultValue: excludeDefault

    parser.addArgument [ '-i', '--initfile' ],
        help: """Write all global initialization out to 'file'."""
        metavar: "file"

    parser.addArgument [ '--path' ],
        help: """Specify how to show the path for each filename in the instrumented output.  If
          'pathtype' is 'relative', then the relative path will be written to each file.  If
          'pathtype' is 'abbr', then we replace each directory in the path with its first letter.
          The default is 'none' which will write only the filename with no path."""
        metavar: "pathtype"
        choices: ['none', 'abbr', 'relative']
        defaultValue: "none"

    parser.addArgument ["src"],
        help: "A file or directory to instrument.  If this is a directory, then all .coffee " +
              "files in this directory and all subdirectories will be instrumented."

    parser.addArgument ["dest"],
        help: "If src is a file then this must be a file to write the compiled JS code to. " +
              "If src is a directory, then this must be a directory.  This file or directory " +
              "will be created if it does not exist."

    options = parser.parseArgs(args)

    # Split exclude into an array.
    if options.exclude
        options.exclude = options.exclude.split ","
    else
        options.exclude = []

    return options

exports.main = (args) ->
    try
        options = parseArgs(args[2..])

        if options.bare
            options.bare = true

        coverageInstrumentor = new CoverageInstrumentor(bare: options.bare)

        if options.verbose
            coverageInstrumentor.on "instrumentingFile", (sourceFile, outFile) ->
                console.log "    #{stripLeadingDotOrSlash sourceFile} to #{stripLeadingDotOrSlash outFile}"

            coverageInstrumentor.on "instrumentingDirectory", (sourceDir, outDir) ->
                console.log "Instrumenting directory: #{stripLeadingDotOrSlash sourceDir} to #{stripLeadingDotOrSlash outDir}"

            coverageInstrumentor.on "skip", (file) ->
                console.log "    Skipping: #{stripLeadingDotOrSlash file}"


        # Change initFile into a output stream
        if options.initfile
            mkdirs path.dirname options.initfile
            options.initFileStream = fs.createWriteStream options.initfile

        result = coverageInstrumentor.instrument options.src, options.dest, options

        options.initFileStream?.end()

        console.log "Annotated #{result.lines} lines."

    catch err
        if err.constructor.name == "CoverageError"
            console.error "Error: #{err.message}"
            process.exit 1
        else
            throw err


if require.main == module
    exports.main(process.argv)
