
{nodes} = require 'coffee-script'
{Block, Code, Assign, Call} = require 'coffee-script/lib/coffee-script/nodes'

module.exports.LineDataInstrument = class LineDataInstrument extends Block

    constructor : (node, @coverageVar) ->

        super()
        @locationData = node.locationData
        @expressions.push nodes "#{@coverageVar}[#{@locationData.first_line}]++"
        @expressions.push node

    initCoverage: ->

        "#{@coverageVar}[#{@locationData.first_line}] = 0;"



module.exports.FunctionDataInstrument = class FunctionDataInstrument extends Code

    constructor : (node, @coverageVar) ->

        super()
        @locationData = node.locationData

    initCoverage: ->

        "#{@coverageVar}.functionData[@name] = new FunctionData();"




###

if expr
    expr
else if expr
    if expr
        expr
    else
        expr
else
    expr


if expr else expr

if expr

unless expr

while expr

until expr

switch expr


if ((a > b or c < d) and
   (d > e)) or
   f == true

    expr

else

    expr


if (((a > b or c < d) and (d > e)) or (f == true)) then expr else expr


must result in a branch data object with two main branches, namely

1: if
2: else

TODO
a > b
2: c < d
3: 1 or 2
4: d > e
5: 3 and 4
6: f == true
7: 5 or 6
8: else

###

class BranchData

    constructor : (@line, @column = 0) ->

        @branches = {}

    addBranch : (@line, @column) ->

    initFragment : ->


class FunctionData

    constructor : (@line, @column) ->

    initFragment : ->

    



# Simple registry used for looking up visitor instances used for
# instrumenting the existing code.
class VisitorLookup

    constructor : ->

        @visitors = []

    addVisitor : (visitor) ->

        if Array.isArray visitor

            @visitors.concat visitor

        else

            @visitors.push visitor

        undefined

    # @return {BaseVisitor} or null
    findVisitor : (node) ->

        result = null

        for visitor in @visitors

            if visitor.canVisit node

                result = visitor
                break

        result


class VisitationOptions

    constructor : (options = {})

        # name of the child(ren) providing property
        # in the parent node or 'expressions'
        @property = options.property || 'expressions'

        # index position of the node in the parent's
        # child(ren) providing property or null
        # if the node is the value of that property,
        # e.g. IfNode#condition
        @index = options.index || null


        # map containing branch data objects for
        # keeping track of branches or the empty map
        # maps source lines to branch data objects
        @branchData = options.branchData || {}

        # map containing function data objects for
        # keeping track of functions or the empty map
        # maps source lines to function data objects
        @functionData = options.functionData || {}

        # true whether this is a chained if statement
        # see IfVisitor#visit for more information
        @chainedIf = options.chainedIf || false


class VisitationResult

    constructor : (options = {})

        # instruct calling visitor to skip next line,
        # see for example LabelVisitor#visit
        @skipNext = options.skipNext || false

        @functionData = options.functionData || null

        @branchData = options.branchData || null

        # array of line data objects or null
        # for each instrumented line an instance of
        # LineData must be created
        # the line data objects will add to the
        # instrumented file's header
        @lineData = options.lineData || null


class BaseVisitor

    canVisit : (node) ->

        return @type == nodeType node

    # @return {VisitationResult} or null
    visit : (node, childName = null, childIndex = null, parent = null, init, lookup) ->

        throw new Error 'not implemented'


class CommentVisitor extends BaseVisitor

    @type = 'Comment'

    visit : (node, childName = null, childIndex = null, parent = null, init, lookup) ->

        # nop


class AssignVisitor extends BaseVisitor

    @type = 'Assign'

    visit : (node, childName = null, childIndex = null, parent = null, init, lookup) ->

        throw new Error 'not implemented'


class IfVisitor extends BaseVisitor

    @type = 'If'

    visit : (node, childName = null, childIndex = null, parent = null, init, lookup) ->

        throw new Error 'not implemented'


class CallVisitor extends BaseVisitor

    @type = 'Call'

    visit : (node, childName = null, childIndex = null, parent = null, init, lookup) ->

        throw new Error 'not implemented'


class WhileVisitor extends BaseVisitor

    @type = 'While'

    visit : (node, childName = null, childIndex = null, parent = null, init, lookup) ->

        throw new Error 'not implemented'


class LabelVisitor extends BaseVisitor

    @type = 'Value'

    canVisit : (node) ->

        return super(node) and
               /^[a-z_$A-Z]+[a-z_$A-Z0-9]*:\s*[/][/]\s*$/.test expression.base?.value

    visit : (node, childName = null, childIndex = null, parent = null, init, lookup) ->

        throw new Error 'not implemented'


