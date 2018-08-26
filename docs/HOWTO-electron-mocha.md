Running with [Electron-mocha](https://github.com/jprichardson/electron-mocha)
---------------------------------------------------------------

Contents
========

* [Quick Start with Electron-mocha](#quick-start-with-electron-mocha)
  * [Run with NPM](#run-with-npm)

Quick Start with Electron-mocha and Nyc
---------------------------------------

Electron-mocha is an awesome project allowing you to test your sources within electron processes, either main or renderer.

[Nyc](https://github.com/istanbuljs/nyc) is the latest Istanbul command line interface, which simplifies a lot instrumentation and reporting.

Assuming you have a coffee-script/electron project with tests cases stored in /test, `cd` to your project and run:

    npm install --save-dev coffee-coverage nyc electron-mocha

Now you're ready to run your tests

    ./node_modules/.bin/nyc --reporter lcov --reporter text ./node_modules/.bin/electron-mocha --renderer --compilers coffee:coffee-script/register -r coffee-coverage/register-istanbul -R spec test/**/*.coffee

Run with NPM
============

Save your mocha options in `/test/mocha.opts`:

```sh
--require coffeescript/register
--require coffee-coverage/register-istanbul
--reporter spec
```

In package.json, add:

```json
"scripts": {
    "test": "nyc electron-mocha --renderer test/**/*.coffee"
}
...
"nyc": {
    "reporter": ["lcov","text"]
},
...
``

now you can run `npm test` to run your tests and generate a coverage report, both in console and in `coverage/lcov-report/index.html`