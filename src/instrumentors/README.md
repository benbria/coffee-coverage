This folder contains "instrumentors" which instrument the code in different ways.
`JSCoverageInstrumentor.coffee` will instrument the code in a way which is compatible with
JSCoverage, for example, while `InstanbulInstrumentor.coffee` will similarly genrate
instrumented code compatible with Istanbul.

Each instrumentor should implement the following functions:

* `visit{Type}(node, nodeData)` - called for each node of the given Type.  For example, `visitIf()`
  will be called once for each If statement in the AST.  Nodes are visited in-order.
  `nodeData` will be a `{parent, childIndex, childAttr, depth}` object which describes where the
  node is found relative to its parent.  Note that `childIndex` is more of a best-case-hint, since
  inserting nodes will change the order of nodes in the parent.
* `visitStatement(node, nodeData)` - similar to `visit{Type}()`, but called only on nodes which
  are statements (nodes where the parent is a 'Block' and where the node is note a 'Comment').
  If a `visit{Type}` exists for the node, it will be called after `visitStatement()`.
* `getInitString()` - called after all nodes are visited, this should generate a JavaScript fragment
  which will be appended to the beginning of the source file (and will also be appended to the
  `initFileStream` if it exists.)

Note the handy helper function `insertBeforeNode(node, nodeData, csString)` which will compile a
string of coffee-script and insert it into the source immediately before `node`.