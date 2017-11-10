# Visitor which looks for pragma directives for skipping coverage, and marks coffeescript nodes
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
            origNode = node
            if node.type is "Value"
                if node.parent.type is "Assign" or node.parent.type is "Switch" or node.parent.type is "Class"
                    node = node.parent
                else
                    node = node.parent.parent
            else if node.type isnt "If"
                node = node.parent

            unless node
                throw new Error "Pragma '#{match[0]}' at #{self._toLocString origNode} has no next statement"

            node.markAll 'skip', true
    }

    # '!pragma coverage-skip-block'
    {
        regex: /^!pragma\s+coverage-skip-block$/
        fn: (self, node, match, options={}) ->
            parent = node.parent.parent.parent

            parent.markAll 'skip', true

            if parent.parent.type is 'If'
                ifBody = parent
                ifNode = parent.parent
                if ifBody.childName is 'body'
                    ifNode.mark 'skipIf', true
                else
                    ifNode.mark 'skipElse', true
    }

    # '!pragma no-coverage-next'
    #
    # Mark the next node and all descendants as `noCoverage`.
    {
        regex: /^!pragma\s+no-coverage-next$/
        fn: (self, node, match, options={}) ->
            if node.type is "Value"
                if node.parent.type is "Assign" or node.parent.type is "Switch" or node.parent.type is "Class"
                    node = node.parent
                else
                    node = node.parent.parent
            else if node.type isnt "If"
                node = node.parent
            node.markAll 'noCoverage', true
    }

    # 'istanbul ignore if'
    #
    # Must be before an `If` statement.  Mark the `If` as `skipIf`, and mark all children in
    # the `body` as `skip`.
    {
        istanbulRegex: /^istanbul\s+ignore\s+if$/
        fn: (self, node, match, options={}) ->
            if node.type is "IdentifierLiteral"
                return
            if node.type is "Value" and node.node.base.constructor?.name is "PassthroughLiteral"
                throw new Error "Pragma '#{match[0]}' at #{self._toLocString node} has no next statement"

            ifNode = self.getIfNode node, match
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
            if node.type is "IdentifierLiteral"
                return
            if node.type is "Value" and node.node.base.constructor?.name is "PassthroughLiteral"
                throw new Error "Pragma '#{match[0]}' at #{self._toLocString node} has no next statement"

            ifNode = self.getIfNode node, match
            ifNode.mark 'skipElse', true
            ifNode.child('elseBody')?.markAll 'skip', true
    }

]

module.exports = class SkipVisitor
    constructor: (@fileName) ->

    visitComment: (node) ->
        if node.node.comments.visited
            return

        comment = node.node.comments[0].content.trim().toLowerCase() ? ''
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

        node.node.comments.visited = true

    _toLocString: (node) ->
        return "#{@fileName} (#{node.locationData.first_line + 1}:#{node.locationData.first_column + 1})"

    getIfNode: (node, match) ->
        if node.type is "If"
            return node
        if node.parent?.parent?.type is "If"
            return node.parent.parent
        if node.parent?.parent?.parent?.type is "If"
            return node.parent.parent.parent

        throw new Error "Statement after pragma '#{match[0]}' at #{@_toLocString node} is not of type If"
