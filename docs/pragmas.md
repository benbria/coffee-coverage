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
            ### !pragma coverage-skip-next ###
            if !@head then throw new Error "I keep losing my head"
            @head = {next: @head, value}

Note that pragmas MUST be in a block comment, by itself:

    ### !pragma coverage-skip-next ###
    console.log "This line will be ignored for coverage purposes."
    # !pragma coverage-skip-next
    console.log "This line will be counted as normal for coverage purposes."
    ###
    # Blah blah blah
    # !pragma coverage-skip-next
    ###
    console.log "This line will be counted as normal, too."

Pragmas will ignore other comment lines, so you can still use JSDoc-like libraries:

    ### !pragma coverage-skip-next ###
    ###
    Create a book.
    @param {string} title - The title of the book.
    @param {string} author - The author of the book.
    ###
    book(title, author) -> ...

Here the pragma will skip the `book` function, and not the comment.

Reference
=========

### ### !pragma coverage-skip-next ### ###

Skips the next statement in the current block, and all children of that statement (for example,
a `### !pragma coverage-skip-next ###` before a `while` statement will make coffee-coverage ignore
the `while` statement itself, as well as all the statements inside the `while` block.)

### ### !pragma coverage-skip-block ### ###

Skips the enclosing block.  For example:

    if process.env.NODE_ENV is 'production'
        ### !pragma coverage-skip-block ###
        console.log "Starting in prod mode!"
        server.listen 80
    else
        server.listen 8080

Everything in the `if` case will be skipped.  Or in a switch statement:

    port = switch NODE_ENV
        when 'production'
            ### !pragma coverage-skip-block ###
            80
        else
            8080

Here everything in the `when 'production'` block will be skipped.  Note you can skip a whole file by putting a
'coverage-skip-block' pragma at the top level of the file.

### ### !pragma no-coverage-next ### ###

This is similar to `coverage-skip-next`, except the affected lines will not only be ignored by
Istanbul for coverage, the lines will not be instrumented at all.  This is handy when you're
calling something like [MongoDB's `mapReduce()`](http://docs.mongodb.org/manual/reference/method/db.collection.mapReduce/#mapreduce-reduce-mtd),
which serializes the function and runs it in some other context, where the global variables used
for instrumentation do not exist.

### Istanbul Pragmas

coffee-coverage will respect [Istanbul style pragmas](https://github.com/gotwarlost/istanbul#ignoring-code-for-coverage).

    ### istanbul ignore if ###
    if process.env.NODE_ENV is 'production'
        server.listen 80
    else
        server.listen 8080
