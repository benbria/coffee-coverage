{expect} = require 'chai'
FILENAME = '/Users/jwalton/foo.coffee'

module.exports = (run) ->
    describe 'Pragmas', ->
        it "should skip statements", ->
            ['### !pragma coverage-skip-next ###', '### istanbul ignore next ###'].forEach (skipPragma) ->
                {instrumentor, result} = run """
                    console.log "hello"
                    #{skipPragma}
                    console.log "world"
                    console.log "!"
                """, counts: {f: 0, s: 3, b: {}}

                expect(instrumentor.statementMap[0].skip).to.not.exist
                expect(instrumentor.statementMap[1].skip).to.be.true
                expect(instrumentor.statementMap[2].skip).to.not.exist

        it "should skip if", ->
            pragmaStyle = """
                console.log "hello"
                if x
                    ### !pragma coverage-skip-block ###
                    console.log "world"
                else
                    console.log "earth"
            """
            istanbulStyle = """
                console.log "hello"
                ### istanbul ignore if ###
                if x
                    console.log "world"
                else
                    console.log "earth"
            """

            [
                {name: 'pragma', source: pragmaStyle},
                {name: 'istanbul', source: istanbulStyle}
            ].forEach ({name, source}) ->
                {instrumentor, result} = run source, counts: {f: 0, s: 4, b: {1:2}}

                expect(instrumentor.statementMap[0].skip, "#{name}-s0").to.not.exist
                expect(instrumentor.statementMap[1].skip, "#{name}-s1").to.not.exist
                expect(instrumentor.statementMap[2].skip, "#{name}-s2").to.be.true
                expect(instrumentor.statementMap[3].skip, "#{name}-s3").to.not.exist

                expect(instrumentor.branchMap[0].locations[0].skip, "#{name}-b0").to.be.true
                expect(instrumentor.branchMap[0].locations[1].skip, "#{name}-b1").to.not.exist

        it "should skip else", ->
            pragmaStyle = """
                console.log "hello"
                if x
                    console.log "world"
                else
                    ### !pragma coverage-skip-block ###
                    console.log "earth"
            """
            istanbulStyle = """
                console.log "hello"
                ### istanbul ignore else ###
                if x
                    console.log "world"
                else
                    console.log "earth"
            """

            [
                {name: 'pragma', source: pragmaStyle},
                {name: 'istanbul', source: istanbulStyle}
            ].forEach ({name, source}) ->
                {instrumentor, result} = run source, counts: {f: 0, s: 4, b: {1:2}}

                expect(instrumentor.statementMap[0].skip, "#{name}-s0").to.not.exist
                expect(instrumentor.statementMap[1].skip, "#{name}-s1").to.not.exist
                expect(instrumentor.statementMap[2].skip, "#{name}-s2").to.not.exist
                expect(instrumentor.statementMap[3].skip, "#{name}-s3").to.be.true

                expect(instrumentor.branchMap[0].locations[0].skip, "#{name}-b0").to.not.exist
                expect(instrumentor.branchMap[0].locations[1].skip, "#{name}-b1").to.be.true

        it "should skip branches and contents of an `if` when the whole `if` is skipped", ->
            ['### !pragma coverage-skip-next ###', '### istanbul ignore next ###'].forEach (skipPragma) ->
                {instrumentor, result} = run """
                    console.log "hello"
                    #{skipPragma}
                    if x
                        console.log "world"
                    else
                        console.log "earth"
                """, counts: {f: 0, s: 4, b: {1:2}}

                expect(instrumentor.statementMap[0].skip, "s0").to.not.exist
                expect(instrumentor.statementMap[1].skip, "s1").to.be.true
                expect(instrumentor.statementMap[2].skip, "s2").to.be.true
                expect(instrumentor.statementMap[3].skip, "s3").to.be.true

                expect(instrumentor.branchMap[0].locations[0].skip, "b0").to.be.true
                expect(instrumentor.branchMap[0].locations[1].skip, "b1").to.be.true

        it "should skip if and else, even when one is missing.", ->
            ['### !pragma coverage-skip-next ###', '### istanbul ignore next ###'].forEach (skipPragma) ->
                {instrumentor, result} = run """
                    console.log "hello"
                    #{skipPragma}
                    if x
                        console.log "world"
                """, counts: {f: 0, s: 3, b: {1:2}}

                expect(instrumentor.statementMap[0].skip, "s0").to.not.exist
                expect(instrumentor.statementMap[1].skip, "s1").to.be.true
                expect(instrumentor.statementMap[2].skip, "s2").to.be.true

                expect(instrumentor.branchMap[0].locations[0].skip, "b0").to.be.true
                expect(instrumentor.branchMap[0].locations[1].skip, "b1").to.be.true

        it "should skip branches and contents of a `switch` when the whole `switch` is skipped", ->
            ['### !pragma coverage-skip-next ###', '### istanbul ignore next ###'].forEach (skipPragma) ->
                {instrumentor, result} = run """
                    console.log "hello"
                    #{skipPragma}
                    switch x
                        when 0 then console.log "world"
                        when 1 then console.log "shazam"
                        else console.log "boom"
                    console.log "!"
                """, counts: {f: 0, s: 6, b: {1:3}}

                expect(instrumentor.statementMap[0].skip, "s0").to.not.exist
                instrumentor.statementMap[1..4].forEach (s, i) -> expect(s.skip, "s#{i+1}").to.be.true
                expect(instrumentor.statementMap[5].skip, "s5").to.not.exist

                instrumentor.branchMap[0].locations.forEach (l, i) ->
                    expect(l.skip, "b0l#{i}").to.be.true

        it "should skip a function correctly", ->
            ['### !pragma coverage-skip-next ###', '### istanbul ignore next ###'].forEach (skipPragma) ->
                {instrumentor, result} = run """
                    console.log "hello"
                    #{skipPragma}
                    a = ->
                        console.log "foo"
                """, counts: {f: 1, s: 3, b: {}}

                expect(instrumentor.statementMap[0].skip, "s0").to.not.exist
                instrumentor.statementMap[1..2].forEach (s, i) -> expect(s.skip, "s#{i+1}").to.be.true

                expect(instrumentor.fnMap[0].skip).to.be.true

        it "should skip a branch in a switch statement", ->
            {instrumentor, result} = run """
                console.log "hello"
                switch process.env.NODE_ENV
                    when 'production'
                        ### !pragma coverage-skip-block ###
                        console.log "prod!"
                    when 'test'
                        console.log "test"
                    else
                        ### !pragma coverage-skip-block ###
                        throw new Error "I know nothing."

            """, counts: {f: 0, s: 5, b: {1:3}}

            expect(instrumentor.statementMap[0].skip, "s0").to.not.exist
            expect(instrumentor.statementMap[1].skip, "s1").to.not.exist
            expect(instrumentor.statementMap[2].skip, "s-prod").to.be.true
            expect(instrumentor.statementMap[3].skip, "s-test").to.not.exist
            expect(instrumentor.statementMap[4].skip, "s-else").to.be.true

            expect(instrumentor.branchMap[0].locations[0].skip, "b-prod").to.be.true
            expect(instrumentor.branchMap[0].locations[1].skip, "b-test").to.not.exist
            expect(instrumentor.branchMap[0].locations[2].skip, "b-else").to.be.true

        it "should skip a function in a class correctly", ->
            ['### !pragma coverage-skip-next ###', '### istanbul ignore next ###'].forEach (skipPragma) ->
                {instrumentor, result} = run """
                    class Foo
                        #{skipPragma}
                        a: ->
                            console.log "foo"
                """, counts: {f: 2, s: 2, b: {}}

                expect(instrumentor.statementMap[0].skip, "s0").to.not.exist
                expect(instrumentor.statementMap[1].skip, "s2").to.be.true

                expect(instrumentor.fnMap[0].skip).to.not.exist
                expect(instrumentor.fnMap[1].skip).to.be.true

        it "should throw an error when a pragma is at the end of a block or file", ->
            expect ->
                run """
                    myFunc = ->
                        console.log "foo"
                        ### !pragma coverage-skip-next ###
                """
            .to.throw "Pragma '!pragma coverage-skip-next' at #{FILENAME} (3:5) has no next statement"

            expect ->
                run """
                    myFunc = ->
                        console.log "foo"
                    ### istanbul ignore if ###
                """
            .to.throw "Pragma 'istanbul ignore if' at #{FILENAME} (3:1) has no next statement"

        it "should throw an error when an 'if' pragma isn't before an 'if'", ->
            expect ->
                run """
                    ### istanbul ignore if ###
                    myFunc = ->
                        console.log "foo"
                """
            .to.throw "Statement after pragma \'istanbul ignore if\' at #{FILENAME} (1:1) is not of type If"
