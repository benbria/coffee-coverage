path                = require 'path'
{expect}            = require 'chai'
sinon               = require 'sinon'

coffeeCoverage      = require("../../src/coffeeCoverage")
Istanbul            = require '../../src/instrumentors/Istanbul'

{COVERAGE_VAR, log} = require '../testConfig'
testUtils           = require '../utils'
FILENAME = '/Users/jwalton/foo.coffee'

checkStatementsAreCovered = (instrumentor, result, statementCount, filename=FILENAME) ->
    expect(instrumentor.statementMap.length, 'statement count').to.equal statementCount
    [1..statementCount].forEach (id) ->
        expect(result.js, "statement #{id} should be instrumented")
        .to.contain "#{COVERAGE_VAR}[\"#{filename}\"].s[#{id}]++"

# `sizeForBranch` is a hash of branch IDs to branch numbers.  e.g. for a `switch` with three cases,
# you would supply `{1: 3}`
checkBranchesAreCovered = (instrumentor, result, sizeForBranchId, filename=FILENAME) ->
    branchCount = Object.keys(sizeForBranchId).length
    expect(instrumentor.branchMap.length, 'branch count').to.equal branchCount

    Object.keys(sizeForBranchId).forEach (branchId, branchIndex) ->
        expectedLocationCount = sizeForBranchId[branchId]

        expect(instrumentor.branchMap[branchIndex].locations.length).to.equal expectedLocationCount

        [0...expectedLocationCount].forEach (locNumber) ->
            expect(result.js, "branch #{branchId}[#{locNumber}] should be instrumented")
            .to.contain "#{COVERAGE_VAR}[\"#{filename}\"].b[#{branchId}][#{locNumber}]++"

checkFunctionsAreCovered = (instrumentor, result, fnCount, filename=FILENAME) ->
    expect(instrumentor.fnMap.length, "functions found").to.equal fnCount
    [1...fnCount+1].forEach (id) ->
        expect(result.js, "function #{id} should be instrumented")
        .to.contain "#{COVERAGE_VAR}[\"#{filename}\"].f[#{id}]++"


exports.run = run = (source, options={}) ->
    filename = options.filename ? FILENAME
    instrumentor = new Istanbul(filename, source, {log, coverageVar: COVERAGE_VAR})
    result = coffeeCoverage._runInstrumentor instrumentor, filename, source, {log}

    if options.counts?.s?
        checkStatementsAreCovered instrumentor, result, options.counts.s, filename
    if options.counts?.b?
        checkBranchesAreCovered instrumentor, result, options.counts.b, filename
    if options.counts?.f?
        checkFunctionsAreCovered instrumentor, result, options.counts.f, filename

    return {instrumentor, result}


describe "Istanbul tests", ->
    it "should find statements", ->
        {instrumentor, result} = run """
            obj.callAFn "Hello world!"
        """, counts: {f: 0, s: 1, b: {}}

        expect(instrumentor.statementMap[0]).to.eql {
            start: {line: 1, column: 0}, end: {line: 1, column: 25}
        }

    it "should find 'if' branches", ->
        {instrumentor, result} = run """
            if x
                obj.callAFn "Hello world!"
            else
                obj.callAFn "Goodbye world!"
        """, {f: 0, s: 3, b: {1:2}}

        expect(instrumentor.statementMap[0], "first statement").to.eql {
            start: {line: 1, column: 0}, end: {line: 4, column: 31}
        }
        expect(instrumentor.statementMap[1], "second statement").to.eql {
            start: {line: 2, column: 4}, end: {line: 2, column: 29}
        }
        expect(instrumentor.statementMap[2], "third statement").to.eql {
            start: {line: 4, column: 4}, end: {line: 4, column: 31}
        }

        expect(instrumentor.branchMap[0]).to.eql {
            line: 1
            loc: {start: {line: 1, column: 0}, end: {line: 1, column: 0}}
            type: 'if'
            locations: [
                {start: {line: 1, column: 0}, end: {line: 1, column: 0}}
                {start: {line: 1, column: 0}, end: {line: 1, column: 0}}
            ]
        }

    it "should find 'unless' branches", ->
        {instrumentor, result} = run """
            unless x
                obj.callAFn "Hello world!"
            else
                obj.callAFn "Goodbye world!"
        """, {f: 0, s: 3, b: {1:2}}

        expect(instrumentor.branchMap[0]).to.eql {
            line: 1
            loc: {start: {line: 1, column: 0}, end: {line: 1, column: 0}}
            type: 'if'
            locations: [
                {start: {line: 1, column: 0}, end: {line: 1, column: 0}}
                {start: {line: 1, column: 0}, end: {line: 1, column: 0}}
            ]
        }

    it "should find chained ifs", ->
        {instrumentor, result} = run """
            if x
                obj.callAFn "1"
            else if y
                obj.callAFn "2"
            else
                obj.callAFn "3"
        """, counts: {f: 0, s: 5, b: {1:2, 2:2}}

        expect(instrumentor.statementMap[0], "if/else if/else").to.eql {
            start: {line: 1, column: 0}, end: {line: 6, column: 18}
        }
        expect(instrumentor.statementMap[1], "obj.callAFn 1").to.eql {
            start: {line: 2, column: 4}, end: {line: 2, column: 18}
        }
        expect(instrumentor.statementMap[2], "if/else if").to.eql {
            start: {line: 3, column: 5}, end: {line: 6, column: 18}
        }
        expect(instrumentor.statementMap[3], "obj.callAFn 2").to.eql {
            start: {line: 4, column: 4}, end: {line: 4, column: 18}
        }
        expect(instrumentor.statementMap[4], "obj.callAFn 3").to.eql {
            start: {line: 6, column: 4}, end: {line: 6, column: 18}
        }

        expect(instrumentor.branchMap[0]).to.eql {
            line: 1
            loc: {start: {line: 1, column: 0}, end: {line: 1, column: 0}}
            type: 'if'
            locations: [
                {start: {line: 1, column: 0}, end: {line: 1, column: 0}}
                {start: {line: 1, column: 0}, end: {line: 1, column: 0}}
            ]
        }
        expect(instrumentor.branchMap[1]).to.eql {
            line: 3
            loc: {start: {line: 3, column: 5}, end: {line: 3, column: 5}}
            type: 'if'
            locations: [
                {start: {line: 3, column: 5}, end: {line: 3, column: 5}}
                {start: {line: 3, column: 5}, end: {line: 3, column: 5}}
            ]
        }

    it "should find if branch with no else", ->
        {instrumentor, result} = run """
            if x
                obj.callAFn "Hello world!"
        """, counts: {f: 0, s: 2, b: {1:2}}

        expect(instrumentor.statementMap[0], "first statement").to.eql {
            # Wha?  Why do these end on different columns?
            start: {line: 1, column: 0}, end: {line: 2, column: 29}
        }
        expect(instrumentor.statementMap[1], "second statement").to.eql {
            start: {line: 2, column: 4}, end: {line: 2, column: 29}
        }

        expect(instrumentor.branchMap[0]).to.eql {
            line: 1
            loc: {start: {line: 1, column: 0}, end: {line: 1, column: 0}}
            type: 'if'
            locations: [
                {start: {line: 1, column: 0}, end: {line: 1, column: 0}}
                {start: {line: 1, column: 0}, end: {line: 1, column: 0}}
            ]
        }

    it "should correctly compile an 'if' which is an expression instead of a statement", ->
        # TODO: Right now this actually instruments the `0` and the `1` as statements.  The
        # generated code looks totally insane, but bizarrely, it actually works.  :P  We might want
        # to explicitly disable this behavior, though...  Have to see if it causes any weird consequences.
        {instrumentor, result} = run 'x = if y then 0 else 1',
            counts: {f: 0, s: 3, b: {1:2}}

        {instrumentor, result} = run 'x = if y then 0',
            counts: {f: 0, s: 2, b: {1:2}}
        expect(result.js).to.contain '(_myCoverageVar["/Users/jwalton/foo.coffee"].b[1][1]++, void 0)'

        {instrumentor, result} = run 'x = if y then else 0',
            counts: {f: 0, s: 2, b: {1:2}}
        expect(result.js).to.contain '(_myCoverageVar["/Users/jwalton/foo.coffee"].b[1][0]++, void 0)'


    it "should correctly compile an 'unless' which is an expression instead of a statement", ->
        # TODO: Right now this actually instruments the `0` and the `1` as statements.  The
        # generated code looks totally insane, but bizarrely, it actually works.  :P  We might want
        # to explicitly disable this behavior, though...  Have to see if it causes any weird consequences.
        {instrumentor, result} = run 'x = unless y then 0 else 1',
            counts: {f: 0, s: 3, b: {1:2}}

        {instrumentor, result} = run 'x = unless y then 0',
            counts: {f: 0, s: 2, b: {1:2}}
        expect(result.js).to.contain '(_myCoverageVar["/Users/jwalton/foo.coffee"].b[1][1]++, void 0)'

    it "should correctly compile an 'if' which is a destructuring expression", ->
        {instrumentor, result} = run '[x,y] = if y then [0,1] else [2,3]',
            counts: {f: 0, s: 3, b: {1:2}}

    it "should find switch/case branches", ->
        {instrumentor, result} = run """
            switch x
                when 1
                    obj.callAFn "a"
                when 2 then obj.callAFn "b"
                else
                    obj.callAFn "c"
        """, counts: {f: 0, s: 4, b: {1:3}}

        expect(instrumentor.statementMap[0], "first statement").to.eql {
            # Should really end on col 22?
            start: {line: 1, column: 0}, end: {line: 6, column: 22}
        }
        expect(instrumentor.statementMap[1], "second statement").to.eql {
            start: {line: 3, column: 8}, end: {line: 3, column: 22}
        }
        expect(instrumentor.statementMap[2], "third statement").to.eql {
            start: {line: 4, column: 16}, end: {line: 4, column: 30}
        }
        expect(instrumentor.statementMap[3], "fourth statement").to.eql {
            start: {line: 6, column: 8}, end: {line: 6, column: 22}
        }

        expect(instrumentor.branchMap[0]).to.eql {
            line: 1
            loc: {start: {line: 1, column: 0}, end: {line: 6, column: 22}}
            type: 'switch'
            locations: [
                {start: {line: 2, column: 4}, end: {line: 3, column: 22}}
                {start: {line: 4, column: 4}, end: {line: 4, column: 30}}
                # TODO: start should really be the start of the `else`.
                {start: {line: 6, column: 8}, end: {line: 6, column: 22}}
            ]
        }

    it "should work for a switch with no 'else'", ->
        {instrumentor, result} = run """
            switch x
                when 1
                    obj.callAFn "a"
                when 2
                    obj.callAFn "b"
        """, counts: {f: 0, s: 3, b: {1:2}}

        expect(instrumentor.branchMap[0]).to.eql {
            line: 1
            loc: {start: {line: 1, column: 0}, end: {line: 5, column: 22}}
            type: 'switch'
            locations: [
                {start: {line: 2, column: 4}, end: {line: 3, column: 22}}
                {start: {line: 4, column: 4}, end: {line: 5, column: 22}}
            ]
        }

    it "should find functions", ->
        {instrumentor, result} = run """
            myFunc = ->
                obj.callAFn "Hello"
        """, counts: {f: 1, s: 2, b: {}}

        expect(instrumentor.statementMap[0], "first statement").to.eql {
            # Should end on 22?
            start: {line: 1, column: 0}, end: {line: 2, column: 22}
        }
        expect(instrumentor.statementMap[1], "second statement").to.eql {
            start: {line: 2, column: 4}, end: {line: 2, column: 22}
        }

        expect(instrumentor.fnMap[0]).to.eql {
            name: 'myFunc'
            line: 1
            loc: {start: {line: 1, column: 9}, end: {line: 2, column: 22}}
            decl: {start: {line: 1, column: 0}, end: {line: 1, column: 10}}
        }

    it "should find functions with parameters", ->
        {instrumentor, result} = run """
            myFunc = (x,y,z) ->
                obj.callAFn "Hello"
        """, counts: {f: 1, s: 2, b: {}}

        expect(instrumentor.fnMap[0]).to.eql {
            name: 'myFunc'
            line: 1
            loc: {start: {line: 1, column: 9}, end: {line: 2, column: 22}}
            decl: {start: {line: 1, column: 0}, end: {line: 1, column: 18}}
        }

    it "should correctly find the end of functions with extra whitespace", ->
        ['->', '=>'].forEach (arrow) ->
            {instrumentor, result} = run """
                myFunc = (x,y,z)   #{arrow}
                    obj.callAFn "Hello"
            """, counts: {f: 1, s: 2, b: {}}

            expect(instrumentor.fnMap[0]).to.eql {
                name: 'myFunc'
                line: 1
                loc: {start: {line: 1, column: 9}, end: {line: 2, column: 22}}
                decl: {start: {line: 1, column: 0}, end: {line: 1, column: 20}}
            }

    it "should find multi-line functions", ->
        {instrumentor, result} = run """
            myFunc = (
                x,
                y,
                z
            ) =>
                obj.callAFn "Hello"
        """, counts: {f: 1, s: 2, b: {}}

        expect(instrumentor.statementMap[0], "first statement").to.eql {
            # Should end on 22?
            start: {line: 1, column: 0}, end: {line: 6, column: 22}
        }
        expect(instrumentor.statementMap[1], "second statement").to.eql {
            start: {line: 6, column: 4}, end: {line: 6, column: 22}
        }

        expect(instrumentor.fnMap[0]).to.eql {
            name: 'myFunc'
            line: 1
            loc: {start: {line: 1, column: 9}, end: {line: 6, column: 22}}
            decl: {start: {line: 1, column: 0}, end: {line: 5, column: 3}}
        }

    it "should find anonymous functions", ->
        {instrumentor, result} = run """
            [1,2,3].forEach -> obj.callAFn "x"
        """, counts: {f: 1, s: 2, b: {}}

        expect(instrumentor.fnMap[0]).to.eql {
            name: '(anonymous_1)'
            line: 1
            loc: {start: {line: 1, column: 16}, end: {line: 1, column: 33}}
            decl: {start: {line: 1, column: 16}, end: {line: 1, column: 17}}
        }

    it "should find anonymous functions with parameters", ->
        {instrumentor, result} = run """
            [1,2,3].forEach (num) -> obj.callAFn num
        """, counts: {f: 1, s: 2, b: {}}

        expect(instrumentor.fnMap[0]).to.eql {
            name: '(anonymous_1)'
            line: 1
            loc: {start: {line: 1, column: 16}, end: {line: 1, column: 39}}
            decl: {start: {line: 1, column: 16}, end: {line: 1, column: 23}}
        }

    it "should use right-most name for funciton with multiple names", ->
        {instrumentor, result} = run """
            x = y = -> obj.callAFn "Hello"
        """, counts: {f: 1, s: 2, b: {}}

        expect(instrumentor.fnMap[0].name).to.equal 'y'


    it "should find functions in a class", ->
        {instrumentor, result} = run """
            class Foo
                constructor: ->
                    @bar = 'Hello World'
                x: -> 2
        """, counts: {f: 3, s: 3, b: {}}

        expect(instrumentor.statementMap[0], "class statement").to.eql {
            # Should end on column 10?
            start: {line: 1, column: 0}, end: {line: 4, column: 10}
        }
        expect(instrumentor.statementMap[1], "constructor body").to.eql {
            start: {line: 3, column: 8}, end: {line: 3, column: 27}
        }
        expect(instrumentor.statementMap[2], "x body").to.eql {
            start: {line: 4, column: 10}, end: {line: 4, column: 10}
        }

        expect(instrumentor.fnMap[0], "class fn").to.eql {
            name: 'Foo'
            line: 1
            loc: {start: {line: 1, column: 0}, end: {line: 4, column: 10}}
            decl: {start: {line: 1, column: 6}, end: {line: 1, column: 8}}
        }
        expect(instrumentor.fnMap[1], "constructor fn").to.eql {
            # TODO: Should this be 'Foo.constructor'?  That would be slick.
            name: 'constructor'
            line: 2
            loc: {start: {line: 2, column: 17}, end: {line: 3, column: 27}}
            decl: {start: {line: 2, column: 4}, end: {line: 2, column: 18}}
        }

    it "should find statements in a class", ->
        {instrumentor, result} = run """
            class Foo
                constructor: ->
                    @bar = 'Hello World'
                console.log 'here'
                x: -> 2
                console.log 'there'
        """, counts: {f: 3, s: 5, b: {}}

    it "should find name of anonymous class", ->
        {instrumentor, result} = run """
            X = class
                constructor: ->
                    @bar = 'Hello World'
        """, counts: {f: 2, s: 2, b: {}}

        expect(instrumentor.fnMap[0], "class fn").to.eql {
            name: '_Class'
            line: 1
            # Not sure these column counts are at all correct, but good enough...
            loc: {start: {line: 1, column: 4}, end: {line: 3, column: 27}}
            decl: {start: {line: 1, column: 4}, end: {line: 1, column: 4}}
        }

    it "should handle labels", ->
        {instrumentor, result} = run """
            counter = 0
            `_l_1: //`
            for x in [1..10]
                if counter == 10
                    break
                `_$l_2: //`
                for y in [1..10]
                    if y == 5 and counter < 10
                        counter++
                        `continue _l_1`
                    `continue _$l_2`
        """, {f: 0, s: 9, b: {1:2, 2:2}}

        expect(instrumentor.statementMap[2], "missing line 3").to.eql {
            start: {line: 4, column: 4}, end: {line: 5, column: 12}
        }

        expect(instrumentor.statementMap[5], "missing line 7").to.eql {
            start: {line: 8, column: 8}, end: {line: 10, column: 26}
        }

    it.skip "should handle import and export statements", ->
        {instrumentor, result} = run """
            import _ from "lodash"
            export default -> 7
        """, {f: 0, s: 3, b: {1:2}}

        console.log result

    findIstanbulVariableNow = Date.now()
    currentCoverageVar = "$$cov_#{findIstanbulVariableNow}$$"
    oldCoverageVar = "$$cov_#{findIstanbulVariableNow - 10}$$"

    testUtils.when( -> !global[currentCoverageVar]? and !global[oldCoverageVar]? )
    .describe 'findIstanbulVariable()', ->
        before ->
            # Stub out `Date.now()` to get predictable behavior
            sinon.stub Date, 'now', -> findIstanbulVariableNow

        after ->
            Date.now.restore()

        it "should return undefined if we're not running inside Istanbul", ->
            expect(Istanbul.findIstanbulVariable()).to.equal undefined

        it "should find the Instabul coverage variable", ->
            global[oldCoverageVar] = {foo: true}
            global[currentCoverageVar] = {foo: true}
            expect(Istanbul.findIstanbulVariable()).to.equal currentCoverageVar
            delete global[currentCoverageVar]

        it "should find an old Instabul coverage variable", ->
            global[oldCoverageVar] = {foo: true}
            expect(Istanbul.findIstanbulVariable()).to.equal oldCoverageVar
            delete global[oldCoverageVar]

    require('./pragmaTests')(run)
    require('./evalTests')()
