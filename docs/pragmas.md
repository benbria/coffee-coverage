Pragmas
-------

coffee-coverage supports conditional instrumentation with pragmas.  Pragmas work for both Istanbul
and JSCoverage instrumentation.

For example, consider the following code block:

    class LinkedList
        push: (value) ->
            if !@head then throw new Error "I keep losing my head"
            @head = {next: @head, value}

This is an example of defensive code, which is good, but it's difficult to write a sensible test
which will exercise this "if" statement without intentionally corrupting your data structure.
It's better to just acknowledge that we don't care about this statement for the purposes of
code coverage and skip it:

    class LinkedList
        push: (value) ->
            ### !pragma coverage-skip ###
            if !@head then throw new Error "I keep losing my head"
            @head = {next: @head, value}

Note that pragmas MUST be in a block comment, by itself:

    ### !pragma coverage-skip ###
    console.log "This line will be ignored for coverage purposes."
    # !pragma coverage-skip
    console.log "This line will be counted as normal for coverage purposes."
    ###
    # Blah blah blah
    # !pragma coverage-skip
    ###
    console.log "This line will be counted as normal, too."

Reference
=========

### ### !pragma coverage-skip ###

Skips the next statement in the current block, and all children of that statement (for example,
a `### !pragma coverage-skip ###` before a `while` statement will make coffee-coverage ignore
the `while` statement itself, as well as all the statements inside the `while` block.)

### ### !pragma coverage-skip-if ###

Used before an `if` statement, this will ignore the 'if' branch for coverage purposes in Istanbul,
and will also ignore all of the statements inside the 'if' branch.

    ### !pragma coverage-skip-if ###
    if process.env.NODE_ENV is 'production'
        server.listen 80
    else
        server.listen 8080

### ### !pragma coverage-skip-else ###

Similar to `### !pragma coverage-skip-if ###`, this ignores the contents of the 'else' branch.

### Istanbul Pragmas

coffee-coverage will respect [Istanbul style pragmas](https://github.com/gotwarlost/istanbul#ignoring-code-for-coverage).

    ### istanbul ignore if ###
    if process.env.NODE_ENV is 'production'
        server.listen 80
    else
        server.listen 8080
