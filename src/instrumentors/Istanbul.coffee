# This is an instrumentor which provides [Istanbul](https://github.com/gotwarlost/istanbul) style
# instrumentation.  This will add a JSON report object to the source code.  The report object is a
# hash where keys are file names (absolute paths), and values are coverage data for that file
# (the result of `json.stringify(collector.fileCoverageFor(filename))`)  Each coverage data
# consists of:
#
# * `path` - The path to the file.  This is an absolute path.
# * `s` - Hash of statement counts, where keys as statement IDs.
# * `b` - Hash of branch counts, where keys are branch IDs and values are arrays of counts.
#         For an if statement, the value would have two counts; one for the if, and one for the
#         else.  Switch statements would have an array of values for each case.
# * `f` - Hash of function counts, where keys are function IDs.
# * `fnMap` - Hash of functions where keys are function IDs, and values are `{name, line, loc}`,
#    where `name` is the name of the function, `line` is the line the function is declared on,
#    and `loc` is the `Location` of the function declaration (just the declaration, not the entire
#    function body.)
# * `statementMap` - Hash where keys are statement IDs, and values are `Location` objects for each
#   statement.  The `Location` for a function definition is really an assignment, and should
#   include the entire function.
# * `branchMap` - Hash where keys are branch IDs, and values are `{line, type, locations}` objects.
#   `line` is the line the branch starts on.  `type` is the type of the branch (e.g. "if", "switch").
#   `locations` is an array of `Location` objects, one for each possible outcome of the branch.
#   Note for an `if` statement where there is no `else` clause, there will still be two `locations`
#   generated.  Istanbul does *not* generate coverage for the `default` case of a switch statement
#   if `default` is not explicitly present in the source code.
#
#   `locations` for an if statement are always 0-length and located at the start of the `if` (even
#   the location for the "else").  For a `switch` statement, `locations` start at the start of the
#   `case` statement and go to the end of the line before the next case statement (note Istanbul
#   does nothing clever here if a `case` is missing a `break`.)
#
# ## Location Objects
#
# Location objects are a `{start: {line, column}, end: {line, column}, skip}` object that describes
# the start and end of a piece of code.  Note that `line` is 1-based, but `column` is 0-based.
# `skip` is optional - if true it instructs Istanbul to ignore if this location has no executions.
#
# An `### istanbul ignore next ###` before a statement would cause that statement's location
# in the `staementMap` to be marked `skip: true`.  For an `if` or a `switch`, this should also
# cause all desendant statments to be marked `skip`, as well as all locations in the `branchMap`.
#
# An `### istanbul ignore if ###` should cause the loction for the `if` in the `branchMap` to be
# marked `skip`, along with all statements inside the `if`.  Similar for
# `### istanbul ignore else ###`.
#
# An `### istanbul ignore next ###` before a `when` in a `switch` should cause the appropriate
# entry in the `branchMap` to be marked skip, and all statements inside the `when`.
# (coffee-script doesn't allow block comments at top scope inside a switch.  Might not be
# able to do this.)
#
# An `### istanbul ignore next ###` before a function declaration should cause the location in
# the `fnMap` to be marked `skip`, the statement for the function delcaration and all statements in
# the function to be marked `skip` in the `statementMap`.
#

assert = require 'assert'
_ = require 'lodash'
NodeWrapper = require '../NodeWrapper'
{toQuotedString} = require '../utils/helpers'
{compareLocations, fileToLines, minLocation} = require '../utils/codeUtils'

nodeToLocation = (node) ->
    # Istanbul uses 1-based lines, but 0-based columns
    answer =
        start:
            line:   node.locationData.first_line + 1
            column: node.locationData.first_column
        end:
            line:   node.locationData.last_line + 1
            column: node.locationData.last_column
    if node.coffeeCoverage?.skip or node.node?.coffeeCoverage?.skip
        answer.skip = true
    return answer

# Find a string in the source code, and return a `{line, column}`.
# Line is 1-based and column is 0-based.
findInCode = (code, str, options={}) ->
    start = options.start ? {line: 1, column: 0}
    end = options.end ? {line: code.length + 1, column: 0}

    currentLine = start.line
    currentCol = start.column
    while currentLine < end.line
        column = code[currentLine-1].indexOf(str, currentCol)
        if column > -1 and compareLocations({line: currentLine, column}, end) < 1
            return {line: currentLine, column}
        currentLine++
        currentCol = 0
    return null

module.exports = class Istanbul

    # Return default options for this instrumentor.
    # TODO: This isn't being called.
    @getDefaultOptions: -> {
        coverageVar: module.exports.findIstanbulVariable() ? '_$coffeeIstanbul'
    }

    # Find the runtime Istanbul variable, if it exists.  Otherwise, fall back to a sensible default.
    @findIstanbulVariable: ->
        coverageVar = "$$cov_#{Date.now()}$$"

        if !global[coverageVar]?
            coverageVars = Object.keys(global)
                .filter (key) -> _.startsWith key, '$$cov_'

            if coverageVars.length is 1
                coverageVar = coverageVars[0]
            else
                # Needs to be undefined and not `null`, because `_.defaults()` treats them differently.
                coverageVar = undefined

        return coverageVar


    # `options` is a `{log, coverageVar}` object.
    #
    constructor: (@fileName, @source, options={}) ->
        {@log, @coverageVar} = options

        # FIXME: Should use sensible default coverageVar
        assert @coverageVar

        @sourceLines = fileToLines @source

        @quotedFileName = toQuotedString @fileName

        @statementMap = []
        @branchMap = []
        @fnMap = []
        @instrumentedLineCount = 0
        @anonId = 1

        @_prefix = "#{@coverageVar}[#{@quotedFileName}]"

    _warn: (message, options={}) ->
        str = message
        str += "\n    file:  #{@fileName}"
        if options.node
            str += "\n    node:  #{options.node.toString()}"
        if options.line
            str += "\n    source: #{@sourceLines[options.line - 1]}"
        @log?.warn str


    visitComment: (node) ->
        # TODO: Respect 'istanbul ignore if', 'istanbul ignore else', and 'istanbul ignore next'?
        # or maybe use 'pragma coverage-skip', 'pragma coverage-skip-if', 'pragma coverage-skip-else'?
        # or both!
        commentData = node.node.comment?.trim() ? ''


    # Called on each non-comment statement within a Block.  If a `visitXXX` exists for the
    # specific node type, it will also be called after `visitStatement`.
    visitStatement: (node) ->
        statementId = @statementMap.length + 1

        location = nodeToLocation(node)
        if node.type is 'If' then location.end = @_findEndOfIf(node)
        @statementMap.push location

        node.insertBefore "#{@_prefix}.s[#{statementId}]++"
        @instrumentedLineCount++

    # coffee-script will put the end of an 'If' statement as being right before the start of
    # the 'else' (which is probably a bug.)  Istanbul expects the end to be the end of the last
    # line in the else (and for chained ifs, Istanbul expects the end of the very last else.)
    _findEndOfIf: (ifNode) ->
        assert ifNode.type is 'If'
        elseBody = ifNode.child 'elseBody'

        if ifNode.node.isChain or ifNode.node.coffeeCoverage?.wasChain
            assert elseBody?
            elseChild = elseBody.child 'expressions', 0
            assert elseChild.type is 'If'
            return @_findEndOfIf elseChild

        else if elseBody?
            return nodeToLocation(elseBody).end

        else
            return nodeToLocation(ifNode).end

    visitIf: (node) ->
        branchId = @branchMap.length + 1

        # Make a 0-length `Location` object.
        ifLocation = nodeToLocation node
        ifLocation.end.line = ifLocation.start.line
        ifLocation.end.column = ifLocation.start.column
        elseLocation = ifLocation

        # Mark each location as `skip` if `skipIf` or `skipElse`.  If the location is
        # already marked `skip`, then we have nothing to do, since all the children are going to
        # be `skip` already.
        if !ifLocation.skip
            elseLocation = _.clone ifLocation
            if node.node.coffeeCoverage?.skipIf then ifLocation.skip = true
            if node.node.coffeeCoverage?.skipElse then elseLocation.skip = true

        @branchMap.push {
            line: ifLocation.start.line
            type: 'if'
            locations: [ifLocation, elseLocation]
        }

        if node.node.isChain
            # Chaining is where coffee compiles something into `... else if ...`
            # instead of '... else {if ...}`.  Chaining produces nicer looking coder
            # with fewer indents, but it also produces code that's harder to instrument
            # (because we can't add code between the `else` and the `if`), so we turn it off.
            #
            @log?.debug? "  Disabling chaining for if statement"
            node.node.isChain = false
            node.node.coffeeCoverage ?= {}
            node.node.coffeeCoverage.wasChain = true

        if !node.isStatement
            # Add 'undefined's for any missing bodies.
            if !node.child('body') then node.insertAtStart 'body', "undefined"
            if !node.child('elseBody') then node.insertAtStart 'elseBody', "undefined"

        node.insertAtStart 'body', "#{@_prefix}.b[#{branchId}][0]++"
        node.insertAtStart 'elseBody', "#{@_prefix}.b[#{branchId}][1]++"
        @instrumentedLineCount += 2

    visitSwitch: (node) ->
        branchId = @branchMap.length + 1
        locations = []
        locations = node.node.cases.map ([conditions, block]) =>
            start = minLocation(
                _.flatten([conditions], true)
                .map( (condition) -> nodeToLocation(condition).start )
            )

            # start.column is the start of the condition, but we want the start of the
            # `when`.
            ### !pragma coverage-skip-else ###
            if (startColumn = @sourceLines[start.line-1]?.indexOf('when')) > -1
                start.column = startColumn
            else
                @_warn "Couldn't find 'when'", {node, line: start.line}
                # Intelligent guess
                start.column -= 5
                if start.column < 0 then start.column = 0

            answer = {start, end: nodeToLocation(block).end}
            if node.node.coffeeCoverage?.skip then answer.skip = true

            return answer

        if node.node.otherwise?
            locations.push nodeToLocation node.node.otherwise

        @branchMap.push {
            line: nodeToLocation(node).start.line
            type: 'switch'
            locations
        }

        node.node.cases.forEach ([conditions, block], index) =>
            caseNode = new NodeWrapper block, node, 'cases', index, node.depth + 1
            assert.equal caseNode.type, 'Block'
            caseNode.insertAtStart 'expressions', "#{@_prefix}.b[#{branchId}][#{index}]++"

        node.forEachChildOfType 'otherwise', (otherwise) =>
            index = node.node.cases.length
            assert.equal otherwise.type, 'Block'
            otherwise.insertAtStart 'expressions', "#{@_prefix}.b[#{branchId}][#{index}]++"

    visitCode: (node) ->
        functionId = @fnMap.length + 1
        paramCount = node.node.params?.length ? 0
        isAssign = node.parent.type is 'Assign' and node.parent.node.variable?.base?.value?

        # Figure out the name of this funciton
        name = if isAssign
            node.parent.node.variable.base.value
        else
            "(anonymous_#{@anonId++})"

        # Find the start and end of the function declaration.
        start = if isAssign
            nodeToLocation(node.parent).start
        else
            nodeToLocation(node).start

        if paramCount > 0
            lastParam = node.child('params', paramCount-1)
            end = nodeToLocation(lastParam).end

            # Coffee-script doesn't tell us where the `->` is, so we have to find it
            arrow = if node.node.bound then '=>' else '->'
            endOfFn = findInCode @sourceLines, arrow, {
                start: {line: end.line, column: end.column},
                end: nodeToLocation(node).end
            }

            ### !pragma coverage-skip-else ###
            if endOfFn
                end = endOfFn
                end.column += 1
            else
                @_warn "Couldn't find '->' or '=>'", {node, line: start.line}
                # Educated guess
                end.column += 4
        else
            end = nodeToLocation(node).start
            # Fix off-by-one error
            end.column++


        loc = {start, end}
        if node.node.coffeeCoverage?.skip then loc.skip = true

        @fnMap.push {name, line: start.line, loc}
        node.insertAtStart 'body', "#{@_prefix}.f[#{functionId}]++"

    visitClass: (node) ->
        functionId = @fnMap.length + 1

        if node.node.variable?
            loc = nodeToLocation(node.node.variable)
        else
            loc = nodeToLocation(node)
            loc.end = loc.start

        @fnMap.push {
            name: node.node.determineName() ? '(anonymousClass)'
            line: loc.start.line
            loc
        }

        node.insertAtStart 'body', "#{@_prefix}.f[#{functionId}]++"

    getInitString: () ->
        initData = {
            path: @fileName
            s: {}
            b: {}
            f: {}
            fnMap: {}
            statementMap: {}
            branchMap: {}
        }

        @statementMap.forEach (statement, id) =>
            initData.s[id + 1] = 0
            initData.statementMap[id + 1] = statement

        @branchMap.forEach (branch, id) =>
            initData.b[id + 1] = (0 for [0...branch.locations.length])
            initData.branchMap[id + 1] = branch

        @fnMap.forEach (fn, id) =>
            initData.f[id + 1] = 0
            initData.fnMap[id + 1] = fn

        init = """
            if (typeof #{@coverageVar} === 'undefined') #{@coverageVar} = {};
            (function(_export) {
                if (typeof _export.#{@coverageVar} === 'undefined') {
                    _export.#{@coverageVar} = #{@coverageVar};
                }
            })(typeof window !== 'undefined' ? window : typeof global !== 'undefined' ? global : this);
            if (! #{@_prefix}) { #{@_prefix} = #{JSON.stringify initData} }
        """

    getInstrumentedLineCount: -> @instrumentedLineCount

