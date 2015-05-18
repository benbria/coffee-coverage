# This is an instrumentor which provides [JSCoverage](http://siliconforks.com/jscoverage/) style
# instrumentation.  This will add a `_$jscoverage` variable to the source code, which is
# a hash where keys are file names, and values are sparse arrays where keys are line number and
# values are the count that the given line was executed.  In addition,
# `_$jscoverage['filename'].source` will be an array containing a copy of the original source code
# split into lines.
#

path = require 'path'
_    = require 'lodash'
{toQuotedString, stripLeadingDotOrSlash, getRelativeFilename} = require '../utils/helpers'
{fileToLines} = require '../utils/codeUtils'

# Generate a unique file name
generateUniqueName = (usedNames, desiredName) ->
    answer = ""
    suffix = 1
    while true
        answer = desiredName + " (" + suffix + ")"
        if not (answer in usedNames) then break
        suffix++

    return answer


module.exports = class JSCoverage

    # Return default options for this instrumentor.
    @getDefaultOptions: -> {
        path: 'bare'
        usedFileNameMap: {}
        coverageVar: '_$jscoverage'
    }

    # `options` is a `{log, coverageVar, basePath, path, usedFileNameMap}` object.
    #
    # * `options.path` should be one of:
    #     * 'relative' - file names will have the `basePath` stripped from them.
    #     * 'abbr' - an abbreviated file name will be constructed, with each parent in the path
    #        replaced by the first character in its name.
    #     * 'bare' (default) - Path names will be omitted.  Only the base file name will be used.
    #
    # * If `options.usedFileNameMap` is present, it must be an object.  This method will add a
    #   mapping from the absolute file path to the short filename in usedFileNameMap. If the name
    #   of the file is already in usedFileNameMap then this method will generate a unique name.
    #
    constructor: (@fileName, @source, options={}) ->
        {@log, @coverageVar} = options

        options = _.defaults {}, options, JSCoverage.getDefaultOptions()

        @instrumentedLines = []

        relativeFileName = getRelativeFilename options.basePath, @fileName

        @shortFileName = options.usedFileNameMap?[@fileName] || do =>
            shortFileName = switch options.path
                when 'relative' then stripLeadingDotOrSlash relativeFileName
                when 'abbr' then @_abbreviatedPath stripLeadingDotOrSlash relativeFileName
                else path.basename relativeFileName

            # Generate a unique fileName if required.
            if options.usedFileNameMap?
                usedFileNames = _.values options.usedFileNameMap
                if shortFileName in usedFileNames
                    shortFileName = generateUniqueName usedFileNames, shortFileName
                options.usedFileNameMap[@fileName] = shortFileName

            shortFileName

        @quotedFileName = toQuotedString @shortFileName

    # Converts a path like "./foo/bar/baz" to "./f/b/baz"
    _abbreviatedPath: (pathName) ->
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

    # Called on each non-comment statement within a Block.  If a `visitXXX` exists for the
    # specific node type, it will also be called after `visitStatement`.
    visitStatement: (node) ->
        # Don't instrument skipped lines.
        return if node.node.coffeeCoverage?.skip

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
            @log?.debug? "Skipping   #{node.toString()}"

        else
            @log?.debug? "Instrumenting #{node.toString()}"
            @instrumentedLines.push line
            node.insertBefore "#{@coverageVar}[#{@quotedFileName}][#{line}]++"

    visitIf: (node) ->
        if node.node.isChain
            # Chaining is where coffee compiles something into `... else if ...`
            # instead of '... else {if ...}`.  Chaining produces nicer looking coder
            # with fewer indents, but it also produces code that's harder to instrument
            # (because we can't add code between the `else` and the `if`), so we turn it off.
            #

            @log?.debug? "  Disabling chaining for if statement"
            node.node.isChain = false

    getInitString: () ->
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
        fileToInstrumentLines = fileToLines @source
        for line, index in fileToInstrumentLines
            if !!index then init += ", "
            init += toQuotedString(line)
        init += "];\n\n"

    getInstrumentedLineCount: -> @instrumentedLines.length
