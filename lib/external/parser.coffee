esprima = require 'esprima'
escodegen = require 'escodegen'


module.exports = new class Parser
	parse: (code, opts)-> esprima.parse code, opts
	parseExpr: (code, opts)-> @parse(expr, opts).body[0].expression
	tokenize: (code, opts)-> esprima.tokenize code, opts
	generate: (ast, opts)-> escodegen.generate ast, opts
	attachComments: (ast)-> escodegen.attachComments ast, ast.comments, ast.tokens