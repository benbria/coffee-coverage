# Visitor which looks for pragma directives for skipping coverage, and marks coffee-script nodes
# to be skipped.
#

_ = require 'lodash'
NodeWrapper = require './NodeWrapper'

PRAGMA_PREFIX = '!pragma'

PRAGMAS = [
    # '!pragma coverage-skip-next', 'istanbul ignore next'
    #
    # Mark the next node and all descendants as `skip`.
    {
        regex: /^!pragma\s+coverage-skip-next$/
        istanbulRegex: /^istanbul\s+ignore\s+next$/
        fn: (self, node, match, options={}) ->
            next = self._getNext(node, match)
            next.markAll 'skip', true
    }

    # '!pragma coverage-skip-block'
    {
        regex: /^!pragma\s+coverage-skip-block$/
        fn: (self, node, match, options={}) ->
            parent = node.parent
            parent.markAll 'skip', true

            if parent.type isnt 'Block'
                ### !pragma coverage-skip-block ###
                throw new Error "Pragma '#{match[0]}' at #{@_toLocString node} is not " +
                    "child of a Block (how did you even do this!?)"

            if parent.parent?.type is 'If'
                ifBody = parent
                ifNode = parent.parent
                if ifBody.childName is 'body'
                    ifNode.mark 'skipIf', true
                else
                    ifNode.mark 'skipElse', true
    }

    # 'istanbul ignore if'
    #
    # Must be before an `If` statement.  Mark the `If` as `skipIf`, and mark all children in
    # the `body` as `skip`.
    {
        istanbulRegex: /^istanbul\s+ignore\s+if$/
        fn: (self, node, match, options={}) ->
            console.log "Found pragma"
            ifNode = self._getNext(node, match, 'If')
            ifNode.mark 'skipIf', true
            ifNode.child('body')?.markAll 'skip', true
    }

    # 'istanbul ignore next'
    #
    # Must be before an `If` statement.  Mark the `If` as `skipElse`, and mark all children in
    # the `elseBody` as `skip`.
    {
        istanbulRegex: /^istanbul\s+ignore\s+else$/
        fn: (self, node, match, options={}) ->
            ifNode = self._getNext(node, match, 'If')
            ifNode.mark 'skipElse', true
            ifNode.child('elseBody')?.markAll 'skip', true
    }

]


module.exports = class SkipVisitor
    constructor: (@fileName) ->

    visitComment: (node) ->
        comment = node.node.comment?.trim().toLowerCase() ? ''
        found = false
        if _.startsWith(comment, PRAGMA_PREFIX)
            PRAGMAS
            .filter (pragma) -> pragma.regex?
            .forEach (pragma) =>
                if match = comment.match(pragma.regex)
                    pragma.fn this, node, match, @options
        else if _.startsWith(comment, 'istanbul')
            PRAGMAS
            .filter (pragma) -> pragma.istanbulRegex?
            .forEach (pragma) =>
                if match = comment.match(pragma.istanbulRegex)
                    pragma.fn this, node, match, @options

    _toLocString: (node) ->
        return "#{@fileName} (#{node.locationData.first_line + 1}:#{node.locationData.first_column + 1})"

    # Verify the given node has a `next`.
    _getNext: (node, match, type=null) ->
        next = node.next()
        if !next?
            throw new Error "Pragma '#{match[0]}' at #{@_toLocString node} has no next statement"
        if type? and next.type isnt type
            throw new Error "Statement after pragma '#{match[0]}' at #{@_toLocString node} is not of type #{type}"
        next

