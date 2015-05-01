Codeship and Coveralls
----------------------

Coveralls support is based on istanbul, so have a look at
[the Istanbul documentation](./HOWTO-istanbul.md) if you run into any problems with Istanbul.  This
HOWTO also assumes you are using mocha, but you should be able to easily get other test frameworks
working.

First, you need your project building in [Codeship](https://codeship.com), and you need your
project set up in [Coveralls.io](https://coveralls.io/).

Assuming you have a coffee-script project with tests cases stored in /test, and you are using
mocha to run your unit tests, `cd` to your project and run:

    npm install --save-dev coffee-coverage
    npm install --save-dev istanbul
    npm install --save-dev coveralls

Save your mocha options in `./test/mocha.opts`:

    --compilers coffee:coffee-script/register
    --require coffee-coverage/register-istanbul
    --recursive

In `package.json`, add:

    "scripts": {
        "citest": "mocha && istanbul report lcovonly"
    }

In codeship, in your project settings, in the "Test" tab, set your "Test Pipeline" to:

    # Build project.  Set this to whatever you use to build:
    npm run prepublish
    # Run CI tests and coverage
    npm run citest
    # Upload results to coveralls.io
    export COVERALLS_SERVICE_NAME=codeship
    export COVERALLS_SERVICE_JOB_ID=${CI_BUILD_NUMBER}
    export COVERALLS_REPO_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    cat ./coverage/lcov.info | ./node_modules/.bin/coveralls

(be sure to set COVERALLS_REPO_TOKEN to your secret token, above.)
