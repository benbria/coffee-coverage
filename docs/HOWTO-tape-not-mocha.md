# Tape not Mocha

It may be hard to believe, but some people don't really like [Mocha](//mochajs.org/). Some of us prefer something simpler and less magical, like [tape](//www.npmjs.com/package/tape). We can still use **coffee-coverage**!

## Setup

First install some necessary modules. Use `--save-dev` because these are only necessary for testing, not for the basic operation of your project.

    npm install --save-dev istanbul coffee-coverage tape coffeetape faucet

[`faucet`](//www.npmjs.com/package/faucet) isn't required, since it is just a pretty-printer, and there are [loads of alternatives](//www.npmjs.com/package/tape#user-content-pretty-reporters) -- pick the one you like. If you don't care for your tests to be pretty, then don't install any of them. Actually not even tape is *really* required, although that's what this HOWTO is about. The point is that **coffee-coverage** works with anything that runs your test code. In this example we use [coffeetape](//www.npmjs.com/package/coffeetape) (so e.g. `test.coffee` never gets transpiled to disk), but we could use plain `node`, plain [`coffee`](//coffeescript.org/#usage), [`tape`](//www.npmjs.com/package/tape#usage), [gulp](//gulpjs.com/), or whatever.

## Write Tests

Let's say you have some code in `index.coffee` in the module directory. In that case your tests might look a bit like the following:

```coffeescript
test = require 'tape'

test 'My Awesome Test, Section 1', (assert) ->
  assert.plan 1                       # if you don't call .plan(), call .end(),
  assert.doesNotThrow ->              # although .plan() is necessary for async
    require './index'
  , null, "requiring module shouldn't cause errors"
```

You can call `test()` any number of times, from any number of test files. Tools (like `faucet`) that understand [TAP](https://testanything.org/) can handle it.

## npm Scripts

If your tests are in a file in the module directory named `test.coffee`, then you could add the following to `package.json`:

```json
"scripts": {
  "pretest": "coffeeCoverage --inst istanbul --exclude test.coffee,node_modules . .",
  "test": "istanbul cover --print none coffeetape test.coffee | faucet",
  "posttest": "istanbul report text-summary"
}
```

The `pretest` will transpile your coffeescript files into "instrumented" javascript files. Typically you'll want to exclude test files, so your coverage statistics are calculated with respect to your actual module, not to your module's tests. (`node_modules` is excluded by default, but if `--exclude` is specified it must be listed.) The `--print none` in the first call to `instanbul` is so that the summary report won't interfere with `faucet`. After that's done, printing the summary in `posttest` will look fine:

```bash
$ npm test

> test2@0.0.0 pretest <my_module>
> coffeeCoverage --inst istanbul --exclude test.coffee,node_modules . .

Instrumented 1 lines.

> test2@0.0.0 test <my_module>
> istanbul cover --print none coffeetape test.coffee | faucet

✓ My Awesome Test, Section 1
# tests 1
# pass  1
✓ ok

> test2@0.0.0 posttest <my_module>
> istanbul report text-summary


=============================== Coverage summary ===============================
Statements   : 90.91% ( 10/11 )
Branches     : 50% ( 5/10 )
Functions    : 100% ( 2/2 )
Lines        : 87.5% ( 7/8 )
================================================================================
Done
```
