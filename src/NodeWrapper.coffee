assert = require 'assert'
coffeeScript = require 'coffee-script'
_ = require 'lodash'

# Wraps a `node` returned from coffee-script's `nodes()` method.
#
# Properties:
# * `node` - The original coffee-script node.
# * `parent` - A `NodeWrapper` object for the parent of the coffee-script node.
# * `childName` - A coffee-script node has multiple named children.  This is the name of the
#   attribute which contains this node in `@parent.node`.  Note that `@parent.node[childName]`
#   may be a single Node or it may be an array of nodes, depending on the implementation of the
#   specific node type.
# * `childIndex` - Where `@parent.node[childName]` is an array, this is the index of `@node`
#   in `@parent.node[childName]`.  Note that inserting new nodes will obviously invalidate this
#   value, so this is more of a "hint" than a hard and fast truism.
# * `depth` - The depth in the AST from the root node.
# * `type` - Copy of @node.constructor.name.
# * `locationData` - Copy of @node.locationData.
# * `isStatement` - true if this node is a statement.
#
module.exports = class NodeWrapper
    constructor: (@node, @parent, @childName, @childIndex, @depth=0) ->
        assert @node
        @locationData = @node.locationData
        @type = @node.constructor?.name or null

        # TODO: Is this too naive?  coffee-script nodes have a `isStatement(o)` function, which
        # really only cares about `o.level`.  Should we be working out the level and calling
        # this function instead of trying to figure this out ourselves?
        @isStatement = @parent? and @type isnt 'Comment' and
            @parent.type is 'Block' and @childName is 'expressions'

        # Note we exclude 'Value' nodes.  When you parse a Class, you'll get Value nodes wrapping
        # each contiguous block of function assignments, and we don't want to treat these as
        # statements.  I can't think of another case where you have a Value as a direct child
        # of an expression.
        if @isStatement and @type is 'Value' and @parent.parent?.type is 'Class'
            @isStatement = false


    # Run `fn(node)` for each child of this node.  Child nodes will be automatically wrapped in a
    # `NodeWrapper`.
    #
    forEachChild: (fn) ->
        if @node.children?
            @node.children.forEach (childName) => @forEachChildOfType childName, fn

    # Like `forEachChild`, but only
    forEachChildOfType: (childName, fn) ->
        children = @node[childName]
        if children?
            childNodes = _.flatten [children], true

            index = 0
            while index < childNodes.length
                child = childNodes[index]
                if child.constructor.name?
                    fn new NodeWrapper(child, this, childName, index, @depth + 1)

                # Bump index up in case we inserted nodes
                # TODO: Guard against incrementing forever?
                index++ while (child != childNodes[index])
                index++

    # Mark this node and all descendants with the given flag.
    markAll: (varName, value) ->
        markCoffeeNode = (coffeeNode) ->
            coffeeNode.coffeeCoverage ?= {}
            coffeeNode.coffeeCoverage[varName] = value
            coffeeNode.eachChild markCoffeeNode
        markCoffeeNode @node

    # Returns a NodeWrapper for the given child.  This only works if the child is not an array
    # (e.g. `Block.expressions`)
    child: (name, index=null) ->
        child = @node[name]
        if !child then return null

        if !index?
            assert !_.isArray child
            return new NodeWrapper child, this, name, 0, @depth + 1
        else
            assert _.isArray child
            if !child[index] then return null
            return new NodeWrapper child[index], this, name, index, @depth + 1

    # `@childIndex` is a hint, since nodes can move around.  This updateds @childIndex if
    # necessary.
    _fixChildIndex: ->
        if !_.isArray @parent.node[@childName]
            @childIndex = 0
        else
            if @parent.node[@childName][@childIndex] isnt @node
                childIndex = _.indexOf @parent.node[@childName], @node
                if childIndex is -1 then throw new Error "Can't find node in parent"
                @childIndex = childIndex

    # Returns this node's next sibling, or null if this node has no next sibling.
    #
    next: ->
        if @parent.type not in ['Block', 'Obj'] then return null
        @_fixChildIndex()
        nextNode = @parent.node[@childName][@childIndex + 1]
        return if !nextNode?
            null
        else
            new NodeWrapper nextNode, @parent, @childName, @childIndex + 1, @depth

    # Insert a new node before this node (only works if this node is in an array-based attribute,
    # like `Block.expressions`.)
    #
    # Note that generated nodes will have the `node.coffeeCoverage.generated` flag set,
    # and will be skipped when instrumenting code.
    #
    insertBefore: (csSource) ->
        assert _.isArray @parent.node[@childName]

        compiled = compile csSource, @node
        @_fixChildIndex()
        @parent.node[@childName].splice(@childIndex, 0, compiled)

    # Insert a chunk of code at the start of a child of this node.  E.g. if this is a Block,
    # then `insertAtStart('expressions', 'console.log "foo"'')` would add a `console.log`
    # statement to the start of the Block's expressions list.
    #
    # Note that generated nodes will have the `node.coffeeCoverage.generated` flag set,
    # and will be skipped when instrumenting code.
    #
    insertAtStart: (childName, csSource) ->
        child = @node[childName]

        if @type is 'Block' and childName is 'expressions'
            if !child
                @node[childName] = [compile(csSource, @node)]
            else
                @node[childName].unshift compile(csSource, @node)

        else if child?.constructor?.name is 'Block'
            child.expressions.unshift compile(csSource, child)

        else if !child
            # This will generate a 'Block'
            @node[childName] = compile(csSource, @node)

        else
            throw new Error "Don't know how to insert statement into #{@type}.#{childName}: #{@type[childName]}"

    toString: ->
        answer = ''
        if @childName then answer += "#{@childName}[#{@childIndex}]:"
        answer += @type
        if @node.locationData? then answer += " (#{@node.locationData?.first_line + 1}:#{@node.locationData.first_column + 1})"

forNodeAndChildren = (node, fn) ->
    fn node
    node.eachChild fn

compile = (csSource, node) ->
    compiled = coffeeScript.nodes(csSource)

    line = node.locationData.first_line

    forNodeAndChildren compiled, (n) ->
        # Fix up location data for each instrumented line.  Make these all 0-length,
        # so we don't have to rewrite the location data for all the non-generated
        # nodes in the tree.
        n.locationData =
            first_line: line - 1 # -1 because `line` is 1-based
            first_column: 0
            last_line: line - 1
            last_column: 0

        # Mark each node as coffee-coverage generated, so we won't try to instrument our
        # instrumented lines.
        n.coffeeCoverage ?= {}
        n.coffeeCoverage.generated = true

    return compiled
