coffee-coverage vs. ibrik
-------------------------

Instrumentation
===============

Here's a code snippet:

    myFunc = (x=7) ->
        return x + 1

    myFunc(6)
    myFunc(7)


Here's the output from `ibrik cover ./src/coverageTest.coffee`:

    Statements   : 87.5% ( 7/8 )
    Branches     : 50% ( 1/2 )
    Functions    : 100% ( 2/2 )
    Lines        : 100% ( 4/4 )

First, note ibrik finds eight statements, two branches, and two functions in the above code.  This
is because ibrik is instrumenting the compiled JavaScript.  The extra function comes from the fact
that the JavaScript version has a `(function(){...}).call(this);` wrapper around the entire block.
The "branch" comes from the default parameter, which will compile to an extra statement
`if (x == null) { x = 7; }`.

Here's the output from coffee-coverage:

    Statements   : 100% ( 4/4 )
    Branches     : 100% ( 0/0 )
    Functions    : 100% ( 1/1 )
    Lines        : 100% ( 4/4 )


This is probably a lot more in line with what you were expecting from this code.
