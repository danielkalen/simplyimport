acorn = require 'acorn'
acornLoose = require 'acorn/dist/acorn_loose'
astring = require 'astring'
extend = require 'extend'
builders = require('ast-types').builders
def = require('ast-types').Type.def
acornOpts =
	sourceType: 'module'
	allowReturnOutsideFunction: true
	allowImportExportEverywhere: true
	preserveParens: true
	comments: true

astringOpts =
	comments: true

module.exports = new class Parser
	parse: (code, opts)-> acornLoose.parse code, extend({}, acornOpts, opts)
	parseStrict: (code, opts)-> acorn.parse code, extend({}, acornOpts, opts)
	parseExpr: (code, opts)-> @parse(code, opts).body[0].expression
	tokenize: (code, opts)-> acorn.tokenizer code, opts
	generate: (ast, opts)-> astring.generate ast, extend({}, astringOpts, opts)
	attachComments: (ast)-> require('escodegen').attachComments ast, ast.comments, ast.tokens
	check: (content, path, opts={sourceType:'module'})-> require('syntax-error-plus')(content, path, opts)


acornLoose.parse = acornLoose.parse_dammit

astring.baseGenerator.ParenthesizedExpression = (node, state)->
	state.write '('
	@[node.expression.type](node.expression, state)
	state.write ')'

astring.baseGenerator.Content = (node, state)->
	state.write(node.content
		.split '\n'
		.map (line,index)-> if not index then line else state.indent.repeat(state.indentLevel)+line
		.join '\n'
	)


def('Content')
	.bases 'Expression'
	.build 'content'
	.field 'content', String
require('ast-types').finalize()


