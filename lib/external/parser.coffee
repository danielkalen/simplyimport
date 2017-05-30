esprima = require 'esprima'
escodegen = require 'escodegen'


module.exports = new class Parser
	parse: (code, opts)-> esprima.parse code, opts
	parseExpr: (code, opts)-> @parse(expr, opts).body[0].expression
	tokenize: (code, opts)-> esprima.tokenize code, opts
	generate: (code, opts)-> escodegen.generate code, opts