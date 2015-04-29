assert = require 'assert'
coffeeScript = require 'coffee-script'
_ = require 'lodash'

# Wraps a `node` returned from coffee-script's `nodes()` method.
#
# Properties:
# * `node` - The original coffee-script node.
# * `parent` - A `NodeWrapper` object for the parent of the coffee-script node.
# * `childAttr` - A coffee-script node has multiple named children.  This is the name of the
#   attribute which contains this node in `@parent.node`.  Note that `@parent.node[childAttr]`
#   may be a single Node or it may be an array of nodes, depending on the implementation of the
#   specific node type.
# * `childIndex` - Where `@parent.node[childAttr]` is an array, this is the index of `@node`
#   in `@parent.node[childAttr]`.  Note that inserting new nodes will obviously invalidate this
#   value, so this is more of a "hint" than a hard and fast truism.
# * `depth` - The depth in the AST from the root node.
# * `type` - Copy of @node.constructor.name.
# * `locationData` - Copy of @node.locationData.
# * `isStatement` - true if this node is a statement.
#
module.exports = class NodeWrapper
    constructor: (@node, @parent, @childAttr, @childIndex, @depth=0) ->
        assert @node
        @locationData = @node.locationData
        @type = @node.constructor?.name or null

        # TODO: Is this too naive?  coffee-script nodes have a `isStatement(o)` function, which
        # really only cares about `o.level`.  Should we be working out the level and calling
        # this function?
        @isStatement = @parent? and @parent.type is 'Block' and @childAttr is 'expressions' and @type isnt 'Comment'

    # Run `fn(node)` for each child of this node.  Child nodes will be automatically wrapped in a
    # `NodeWrapper`.
    #
    forEachChild: (fn) ->
        if @node.children?
            @node.children.forEach (attr) => @forEachChildOfType attr, fn

    # Like `forEachChild`, but only
    forEachChildOfType: (attr, fn) ->
        childAttr = @node[attr]
        if childAttr?
            attrs = _.flatten [childAttr], true

            index = 0
            while index < attrs.length
                child = attrs[index]
                if child.constructor.name?
                    fn new NodeWrapper(child, this, attr, index, @depth + 1)

                # Bump index up in case we inserted nodes
                # TODO: Guard against incrementing forever?
                index++ while (child != attrs[index])
                index++

    # Insert a new node before this node (only works if this node is in an array-based attribute,
    # like `Block.expressions`.)
    #
    # Note that generated nodes will have the `node.coffeeCoverage.generated` flag set,
    # and will be skipped when instrumenting code.
    #
    insertBefore: (csSource) ->
        assert _.isArray @parent.node[@childAttr]

        compiled = compile csSource, @node

        # childIndex is more of a hint, since nodes can move around.
        if @parent.node[@childAttr][@childIndex] isnt @node
            childIndex = _.indexOf @parent.node[@childAttr], @node
            if childIndex is -1 then throw new Error "Can't find node in parent"
            @childIndex = childIndex

        @parent.node[@childAttr].splice(@childIndex, 0, compiled)

    # Insert a chunk of code at the start of a child of this node.  E.g. if this is a Block,
    # then `insertAtStart('expressions', 'console.log "foo"'')` would add a `console.log`
    # statement to the start of the Block's expressions list.
    #
    # Note that generated nodes will have the `node.coffeeCoverage.generated` flag set,
    # and will be skipped when instrumenting code.
    #
    insertAtStart: (attr, csSource) ->
        child = @node[attr]

        if @type is 'Block' and attr is 'expressions'
            if !child
                @node[attr] = [compile(csSource, @node)]
            else
                @node[attr].unshift compile(csSource, @node)

        else if child?.constructor?.name is 'Block'
            child.expressions.unshift compile(csSource, child)

        else if !child
            # This will generate a 'Block'
            @node[attr] = compile(csSource, @node)

        else
            throw new Error "Don't know how to insert statement into #{@type}.#{attr}: #{@type[attr]}"

    toString: ->
        answer = ''
        if @childAttr then answer += "#{@childAttr}[#{@childIndex}]:"
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
