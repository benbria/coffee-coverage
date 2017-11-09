#!/usr/bin/env bash

echo Testing with Coffee-Script v2.0.2
npm install coffeescript@2.0.2
COFFEECOV_OUT=coverage/coverage-coffee-2_0_2.json npm test
npm run coverage-report
