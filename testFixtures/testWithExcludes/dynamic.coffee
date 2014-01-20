require("../../src/coffeeCoverage").register(
  path: "relative"
  basePath: __dirname
  exclude: ["b"]
)

require './a/foo.coffee'
require './b/bar.coffee'
