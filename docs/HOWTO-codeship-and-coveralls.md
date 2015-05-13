Codeship and Coveralls
----------------------

Coveralls support is based on istanbul, so have a look at
[the Istanbul documentation](./HOWTO-istanbul.md) if you run into any problems.  This
HOWTO also assumes you are using mocha, but you should be able to easily get other test frameworks
working.

First, you need your project building in [Codeship](https://codeship.com), and you need your
project set up in [Coveralls.io](https://coveralls.io/).

Assuming you have a coffee-script project with tests cases stored in /test, and you are using
mocha to run your unit tests, `cd` to your project and run:

    npm install --save-dev coffee-coverage istanbul coveralls

Save your mocha options in `./test/mocha.opts`:

    --compilers coffee:coffee-script/register
    --require coffee-coverage/register-istanbul
    --recursive

In `package.json`, add:

    "scripts": {
        "test": "mocha && istanbul report text-summary lcov"
    }

Add this line to your .gitignore and .npmignore:

    /coverage

In Codeship, in your project settings, in the "Environment" tab, set up your Coveralls
credentials:

   COVERALLS_SERVICE_NAME = codeship
   COVERALLS_REPO_TOKEN = [your secret token here]

In the "Test" tab, set your "Test Pipeline" to:

    # Build project.  Set this to whatever you use to build:
    npm run prepublish

    # Run CI tests and coverage
    npm test

    # Upload results to coveralls.io
    export COVERALLS_SERVICE_JOB_ID=${CI_BUILD_NUMBER}
    cat ./coverage/lcov.info | ./node_modules/.bin/coveralls
