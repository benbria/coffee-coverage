Travis-CI and Coveralls
-----------------------

Coveralls support is based on istanbul, so have a look at
[the Istanbul documentation](./HOWTO-istanbul.md) if you run into any problems.  This
HOWTO also assumes you are using mocha, but you should be able to easily get other test frameworks
working.

First, you need to sign up for an account at [Travis-CI](https://travis-ci.org/) and you need
to add your project in [Coveralls.io](https://coveralls.io/).

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

Create a `.travis.yml` file:

    language: node_js
    node_js:
      - '0.10'
      - '0.12'
      - 'iojs'
    after_success:
      - 'cat ./coverage/lcov.info | ./node_modules/.bin/coveralls'

Add this line to your .gitignore and .npmignore:

    /coverage

Push all these changes to github, and Travis-CI should generate a coverage report and send it to
coveralls.  If you'd like to see an example of an application that is set up this way, check out
[jwalton/lol-js](https://github.com/jwalton/lol-js).