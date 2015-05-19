#!/usr/bin/env bash

echo Testing with Coffee-Script v1.7.1
npm install coffee-script@1.7.1
COFFEECOV_OUT=coverage/coverage-coffee-1_7_1.json npm test
echo Testing with Coffee-Script v1.8.0
npm install coffee-script@1.8.0
COFFEECOV_OUT=coverage/coverage-coffee-1_8_0.json npm test
echo Testing with Coffee-Script v1.9.2
npm install coffee-script@1.9.2
COFFEECOV_OUT=coverage/coverage-coffee-1_9_2.json npm test
npm run coverage-report
