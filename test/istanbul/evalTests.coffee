{expect} = require 'chai'
coffeeCoverage = require("../../src/index")

{COVERAGE_VAR, log} = require '../testConfig'

module.exports = -> describe "Eval tests", ->
    afterEach ->
        # Clear coverage
        delete global[COVERAGE_VAR]


    it "should work with debug logging", ->
        instrumentor = new coffeeCoverage.CoverageInstrumentor({
            coverageVar: COVERAGE_VAR
            log: {
                debug: ->
                info: ->
                warn: ->
                error: ->
            }
            instrumentor: 'istanbul'
        })
        source = """
            z = 0
            for i in [0...2]
                for j in [0...5]
                    z++

            return z
        """

        code = instrumentor.instrumentCoffee("example.coffee", source).js

    it "should correctly compile an 'if' without an explicit return", ->
        instrumentor = new coffeeCoverage.CoverageInstrumentor({
            coverageVar: COVERAGE_VAR
            instrumentor: 'istanbul'
        })
        source = """
            f = (x) ->
                if x?.foo then 1

            return f({})
        """
        result = instrumentor.instrumentCoffee("example.coffee", source)
        z = eval result.init + result.js
        expect(z).to.not.exist

    it "should correctly compile 'return if x then val'", ->
        instrumentor = new coffeeCoverage.CoverageInstrumentor({
            coverageVar: COVERAGE_VAR
            instrumentor: 'istanbul'
        })
        source = """
            f = (x) ->
                return if x then 'x'
                return 'y'

            return f()
        """
        result = instrumentor.instrumentCoffee("example.coffee", source)
        z = eval result.init + result.js
        expect(z).to.equal 'y'
        expect(global[COVERAGE_VAR]['example.coffee'].b[1][0], 'if count').to.equal 0
        expect(global[COVERAGE_VAR]['example.coffee'].b[1][1], 'else count').to.equal 1

    it "should correctly compile 'return if x then else val'", ->
        instrumentor = new coffeeCoverage.CoverageInstrumentor({
            coverageVar: COVERAGE_VAR
            instrumentor: 'istanbul'
        })
        source = """
            f = (x) ->
                return if x then else 'x'
                return 'y'

            return f(true)
        """
        result = instrumentor.instrumentCoffee("example.coffee", source)
        z = eval result.init + result.js
        expect(z).to.equal 'y'
        expect(global[COVERAGE_VAR]['example.coffee'].b[1][0], 'if count').to.equal 1
        expect(global[COVERAGE_VAR]['example.coffee'].b[1][1], 'else count').to.equal 0

    it "should ignore 'return if x then else'", ->
        instrumentor = new coffeeCoverage.CoverageInstrumentor({
            coverageVar: COVERAGE_VAR
            instrumentor: 'istanbul'
        })
        source = """
            f = (x) ->
                return if x then else
                return 'y'

            return f(true)
        """
        result = instrumentor.instrumentCoffee("example.coffee", source)
        z = eval result.init + result.js
        expect(z).to.equal 'y'
        expect(global[COVERAGE_VAR]['example.coffee'].branchMap[1].locations[0].skip).to.be.true
        expect(global[COVERAGE_VAR]['example.coffee'].branchMap[1].locations[1].skip).to.be.true

    it "should correctly compile list comprehensions", ->
        instrumentor = new coffeeCoverage.CoverageInstrumentor({
            coverageVar: COVERAGE_VAR
            log: log
            instrumentor: 'istanbul'
        })
        source = """
            a = [1,2,3,4]
            inc = (x) -> x + 1
            a = (inc x for x in a)
            return a
        """
        result = instrumentor.instrumentCoffee("example.coffee", source)
        z = eval result.init + result.js
        expect(z).to.eql [2,3,4,5]

