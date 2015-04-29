# This is an instrumentor which provides [JSCoverage](http://siliconforks.com/jscoverage/) style
# instrumentation.  This will add a `_$jscoverage` variable to the source code, which is
# a hash where keys are file names, and values are sparse arrays where keys are line number and
# values are the count that the given line was executed.  In addition,
# `_$jscoverage['filename'].source` will be an array containing a copy of the original source code
# split into lines.
#

path = require 'path'
{insertBeforeNode, nodeType, toQuotedString, stripLeadingDotOrSlash} = require '../helpers'

# Takes the contents of a file and returns an array of lines.
# `source` is a string containing an entire file.
fileToLines = (source) ->
    dataWithFixedLfs = source.replace(/\r\n/g, '\n').replace(/\r/g, '\n')
    return dataWithFixedLfs.split("\n")

# Converts a path like "./foo/"
abbreviatedPath = (pathName) ->
    needTrailingSlash = no

    splitPath = pathName.split path.sep

    if splitPath[-1..-1][0] == ''
        needTrailingSlash = yes
        splitPath.pop()

    filename = splitPath.pop()

    answer = ""
    for pathElement in splitPath
        if pathElement.length == 0
            answer += ""
        else if pathElement is ".."
            answer += pathElement
        else if _.startsWith pathElement, "."
            answer += pathElement[0..1]
        else
            answer += pathElement[0]
        answer += path.sep

    answer += filename

    if needTrailingSlash
        answer += path.sep

    return answer



module.exports = class JSCoverage
    # `options` is a `{log, coverageVar, path, usedfileNames}` object.
    #
    constructor: (fileName, options) ->
        {@log, @coverageVar} = options
        @instrumentedLines = []

        shortFileName = switch options.path
            when 'relative' then stripLeadingDotOrSlash fileName
            when 'abbr' then abbreviatedPath stripLeadingDotOrSlash fileName
            else path.basename fileName

        # Generate a unique fileName if required.
        if options.usedfileNames
            if shortFileName in options.usedfileNames
                shortFileName = generateUniqueName options.usedfileNames, shortFileName
            options.usedfileNames.push shortFileName

        @quotedFileName = toQuotedString shortFileName


    # Called on each non-comment statement within a Block.  If a `visitXXX` exists for the
    # specific node type, it will also be called after `visitStatement`.
    visitStatement: (node) ->
        line = node.locationData.first_line + 1

        if line in @instrumentedLines
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
            @log?.debug "Skipping   #{node.toString()}"

        else
            @log?.debug "Instrumenting #{node.toString()}"
            @instrumentedLines.push line
            node.insertBefore "#{@coverageVar}[#{@quotedFileName}][#{line}]++"

    visitIf: (node) ->
        if node.node.isChain
            # Chaining is where coffee compiles something into `... else if ...`
            # instead of '... else {if ...}`.  Chaining produces nicer looking coder
            # with fewer indents, but it also produces code that's harder to instrument
            # (because we can't add code between the `else` and the `if`), so we turn it off.
            #

            @log?.debug "  Disabling chaining for if statement"
            node.node.isChain = false

    getInitString: ({source}) ->
        init = """
            if (typeof #{@coverageVar} === 'undefined') #{@coverageVar} = {};
            (function(_export) {
                if (typeof _export.#{@coverageVar} === 'undefined') {
                    _export.#{@coverageVar} = #{@coverageVar};
                }
            })(typeof window !== 'undefined' ? window : typeof global !== 'undefined' ? global : this);
            if (! #{@coverageVar}[#{@quotedFileName}]) {
                #{@coverageVar}[#{@quotedFileName}] = [];\n"""

        for lineNumber in @instrumentedLines
            init += "    #{@coverageVar}[#{@quotedFileName}][#{lineNumber}] = 0;\n"

        init += "}\n\n"

        # Write the original source code into the ".source" array.
        init += "#{@coverageVar}[#{@quotedFileName}].source = ["
        fileToInstrumentLines = fileToLines source
        for line, index in fileToInstrumentLines
            if !!index then init += ", "
            init += toQuotedString(line)
        init += "];\n\n"

    getInstrumentedLineCount: -> @instrumentedLines.length
