Using with Streamline
=====================

CoffeeCoverage supports [streamline](https://github.com/Sage/streamlinejs)'d coffee files.
The easiest way to enable streamline support is by writing a custom loader.  First, install
streamline:

    npm install --save streamline

Write the following to a file called 'registerCoffeeCoverage.js' in your project's root folder:

    path = require('path');

    require('coffee-coverage').register({
        basePath: process.cwd(),
        exclude: ['/test', '/node_modules', '/.git'],
        instrumentor: 'istanbul',
        coverageVar: '_$coffeeIstanbul',
        writeOnExit: 'coverage/coverage-coffee.json',
        streamlinejs: true,
        cachePath: path.join process.cwd(), 'build/coffee-coverage-cache'
        initAll: true
    });

Then, run your tests:

    mocha --require ./registerCoffeeCoverage --reporter html-cov ...

You can also set `streamlinejs` to a set of options to pass to streamline.  Any option you can
pass to [transform](https://github.com/Sage/streamlinejs/blob/master/lib/callbacks/transform.md)
is supported.

It is highly recommended to pass the `cachePath` option when using streamline, as the streamline
compiler can be a bit slow.