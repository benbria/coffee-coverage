Overview
--------
The 5 mile high view of coffee-coverage is; first we use
[coffee-script to parse the input and generate an abstract syntax tree (AST)](https://github.com/benbria/coffee-coverage/blob/c7566d50493ad98953640ccc5e7dc0080576d08a/src/coffeeCoverage.coffee#L319).
Then we visit every node in the AST with an
[instrumentor](https://github.com/benbria/coffee-coverage/tree/master/src/instrumentors) which, generally, adds some
extra nodes into the resulting coffee-script.  Finally we
[compile the resulting AST](https://github.com/benbria/coffee-coverage/blob/c7566d50493ad98953640ccc5e7dc0080576d08a/src/coffeeCoverage.coffee#L350)
out into JavaScript.

All the information about where a particular fragment of source came from is based on the [`locationData`](https://github.com/jashkenas/coffeescript/blob/98dd1bf8e80aa7974422a5fdef3075a9e7329d00/src/helpers.coffee#L98)
found in the coffee-script node.

You'll notice that instrumentors have a
[`getInitString()`](https://github.com/benbria/coffee-coverage/blob/c7566d50493ad98953640ccc5e7dc0080576d08a/src/instrumentors/Istanbul.coffee#L402)
method.  This is used to generate code to initalize any data structures needed for the instrumentation code.  Even
if a given file is never run, if the `--initfile` command line parameter or the `initAll` option is used,
coffee-coverage will generate initialization for all files in the project.  This is how we can get 0% code coverage for
code that never runs.

Istanbul Support
----------------
The goal of Istanbul integration is to generate a coverage.json file that
[istanbul can read](https://github.com/gotwarlost/istanbul/blob/master/coverage.json.md) and generate reports from.

If we're running coffee-coverage directly from mocha, this is pretty easy.  We just instrument all the code to write
instrumentation data to a global variable, then right before the program terminates we [write this global data
out to a JSON file](https://github.com/benbria/coffee-coverage/blob/c7566d50493ad98953640ccc5e7dc0080576d08a/src/register.coffee#L134).

If we're running `istanbul cover` to generate coverage for a project with mixed JS and coffee-script content, then
things get a little more exciting.  The problem is that
[Istanbul generates a unique variable name](https://github.com/gotwarlost/istanbul/blob/c87ada03cb485e4f9110224899b68d8dc27e4bf3/lib/command/common/run-with-cover.js#L158)
for coverage data on every run, which means coffee-coverage needs to
[work out what that variale name is](https://github.com/benbria/coffee-coverage/blob/c7566d50493ad98953640ccc5e7dc0080576d08a/src/instrumentors/Istanbul.coffee#L99-L112).
Otherwise it works much the same, with the exception that we just let Istanbul write out the json file for us.
