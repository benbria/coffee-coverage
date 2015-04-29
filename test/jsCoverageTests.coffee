path = require 'path'
coffeeCoverage = require("../src/coffeeCoverage")
{expect} = require 'chai'

{COVERAGE_VAR, log} = require './testConfig'

checkLinesAreCovered = (code, filename, lineNumbers) ->
    lineNumbers.forEach (l) ->
        expect(code, "line #{l} should be instrumented")
        .to.contain "#{COVERAGE_VAR}[\"#{filename}\"][#{l}]++;"

describe "JSCoverage tests", ->
    it "should un-chain if statements", ->
        instrumentor = new coffeeCoverage.CoverageInstrumentor({
            coverageVar: COVERAGE_VAR
            log: log
        })
        source = """
            if x
                console.log "hello"
            else if y
                console.log "world"
            else
                console.log "!"
        """

        code = instrumentor.instrumentCoffee("example.coffee", source).js
        expect(code.trim()).to.equal '''
            (function() {
              _myCoverageVar["example.coffee"][1]++;

              if (x) {
                _myCoverageVar["example.coffee"][2]++;
                console.log("hello");
              } else {
                _myCoverageVar["example.coffee"][3]++;
                if (y) {
                  _myCoverageVar["example.coffee"][4]++;
                  console.log("world");
                } else {
                  _myCoverageVar["example.coffee"][6]++;
                  console.log("!");
                }
              }

            }).call(this);
        '''
        checkLinesAreCovered code, "example.coffee", [1,2,3,4,6]
