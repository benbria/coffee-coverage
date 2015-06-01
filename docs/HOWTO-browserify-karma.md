Running with [Browserify](https://github.com/substack/node-browserify) and [Karma](http://karma-runner.github.io/0.12/index.html)
---------------------------------------------------------------------------------------------------------------------------------

Contents
========

* [browserify](#instrumenting-with-browserify)
* [karma](#reporting-with-karma)

Instrumenting with Browserify
-----------------------------

If you use browserify in your project, you may also be writing unit tests with browserify bundles. Follow these steps to
instrument your bundles with coffee-coverage.

You can use the browserify transform
[browserify-coffee-coverage](https://www.npmjs.com/package/browserify-coffee-coverage) to get your files instrumented.
Use it instead of `coffeeify` to compile your `*.coffee` test bundle files into `*.js` with the instrumentation added.
You can setup a browserify build such as:

```javascript
var browserify = require('browserify');
var coverage = require('browserify-coffee-coverage');
var b = browserify();
b.add('./foo.coffee');
var options = { noInit: false };
b.transform(coverage, options);
b.bundle();
```

Check out the `browserify-coffee-coverage` repo for more details. One note: the transform will ignore some file patterns
by default, such as `**/node_modules/**`, and will therefore not instrument them. You can also pass in specific
patterns.

Note: This will only get the files you have required in your bundles instrumented. However, it is usually useful to
instrument and report on all of your sources to get a percentage of what you have covered. `coffee-coverage` takes care
of this by walking through your source directory and storing all the initial coverage objects. It seems semantically
incorrect to have `browserify-coffee-coverage` do this, as it is a _transform_ only. So, it has left that job up to the
user. If you plan to use your browserify bundles with `karma`, you can follow the next bit to have it done for you.

Reporting with Karma
--------------------

If you use Karma to run your browserified tests, you can use `karma-coffee-coverage` to report your total coverage. What
you need to do is:

1. Instrument your browserify bundles as mentioned above.
2. Point Karma at your browserify bundles
3. Install `karma-coffee-coverage` and configure it as it mentions
[here](https://www.npmjs.com/package/karma-coffee-coverage#usage)

    What this will do is use `coffee-coverage` to walk through your specified source directory, generate an empty
    coverage object of all your files, and write it to a `js` file. You then tell Karma to load this file into the
    browser (called `coverage-init.js` or something). Along with your instrumented bundles, you will get a full coverage
    count.
4. Install and configure [karma-coverage](https://github.com/karma-runner/karma-coverage) to do the actual reporting.
