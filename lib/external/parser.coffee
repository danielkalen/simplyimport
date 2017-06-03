esprima = require 'esprima'
escodegen = require 'escodegen'
acorn = require 'acorn'
astring = require 'astring'
extend = require 'extend'
acornOpts =
	sourceType: 'module'
	allowReturnOutsideFunction: true
	allowImportExportEverywhere: true
	preserveParens: true
	comments: true

astringOpts =
	comments: true

module.exports = new class Parser
	parse: (code, opts)-> acorn.parse code, extend({}, acornOpts, opts)
	parseExpr: (code, opts)-> @parse(code, opts).body[0].expression
	# tokenize: (code, opts)-> esprima.tokenize code, opts
	tokenize: (code, opts)-> acorn.tokenizer code, opts
	generate: (ast, opts)-> astring.generate ast, extend({}, astringOpts, opts)
	attachComments: (ast)-> require('escodegen').attachComments ast, ast.comments, ast.tokens



astring.baseGenerator.ParenthesizedExpression = (node, state)->
	state.write '('
	@[node.expression.type](node.expression, state)
	state.write ')'