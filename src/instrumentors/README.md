This folder contains "instrumentors" which instrument the code in different ways.
`JSCoverage.coffee` will instrument the code in a way which is compatible with
JSCoverage, for example, while `Istanbul.coffee` will similarly genrate
instrumented code compatible with Istanbul.

Each instrumentor should implement the following functions:

* `constructor(fileName, source, options)`.  `fileName` will be an absolute path.  `source` is a
  copy of the raw source code.  `options` include all the options passed to coffeeCoverage.
* `visit{Type}(node)` - called for each node of the given Type.  For example, `visitIf()`
  will be called once for each If statement in the AST.  Nodes are visited in-order.
  `node` is a `NodeWrapper` object.
* `visitStatement(node)` - similar to `visit{Type}()`, but called only on nodes which
  are statements (nodes where the parent is a 'Block' and where the node is note a 'Comment').
  If a `visit{Type}` exists for the node, it will be called after `visitStatement()`.
* `getInitString()` - called after all nodes are visited, this should generate a JavaScript
  fragment which will be appended to the beginning of the source file (and will also be appended to
  the `initFileStream` if it exists.)
* `@getDefaultOptions()` - (optional) set default options to be passed to this instrumentor.
