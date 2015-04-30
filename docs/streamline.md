Using with Streamline
=====================

CoffeeCoverage supports [streamline](https://github.com/Sage/streamlinejs)'d coffee files.
The easiest way to enable streamline support is by writing a custom loader.  Write the
following to a file called 'registerCoffeeCoverage.js' in your project's root folder:

    // If you're using with streamline, you *must* register streamline first:
    require('streamline').register({});

    require('coffee-coverage').register({
        basePath: process.cwd(),
        exclude: ['/test', '/node_modules', '/.git'],
        instrumentor: 'istanbul',
        coverageVar: '_$coffeeIstanbul',
        writeOnExit: 'coverage/coverage-coffee.json',
        initAll: true
    });

Then, run your tests:

    mocha --require ./registerCoffeeCoverage --reporter html-cov ...

Note that streamline support is "experimental" right now (i.e. it might break at any moment
because we're using undocumented features in streamlinejs) so to turn it on, you have to
explicitly pass 'streamlinejs: true' as an option.
