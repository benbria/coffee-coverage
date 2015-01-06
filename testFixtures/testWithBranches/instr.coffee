
{nodes} = require 'coffee-script'
{Block, Assign, Call} = require 'coffee-script/lib/coffee-script/nodes'

module.exports = class LineDataInstrument extends Block

    constructor : (node, @coverageVar) ->

        super()
        @locationData = node.locationData
        @expressions.push nodes "#{@coverageVar}[#{@locationData.first_line}]++"
        @expressions.push node

    initCoverage: ->

        "#{@coverageVar}[#{@locationData.first_line}] = 0;"

