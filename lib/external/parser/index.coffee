codegen = require './codegen'
extend = require 'extend'
acorn = require 'acorn'
acornLoose = require 'acorn/dist/acorn_loose'
acornLoose.parse = acornLoose.parse_dammit
require './customDef'


class Parser
	opts: (opts)-> extend({}, require('./acornOpts'), opts)
	parse: (code, opts)-> acornLoose.parse code, @opts(opts)
	parseStrict: (code, opts)-> acorn.parse code, @opts(opts)
	parseExpr: (code, opts)-> @parse(code, opts).body[0].expression
	tokenize: (code, opts)-> Array.from acorn.tokenizer code, opts
	generate: (ast, opts)-> require('./codegen').generate ast, opts
	attachComments: (ast)-> require('escodegen').attachComments ast, ast.comments, ast.tokens
	check: (content, path, opts={sourceType:'module'})-> require('syntax-error-plus')(content, path, @opts(opts))
	find: require './find'
	walk: require './walk'
	replaceNode: require './replaceNode'
	renameVariables: require './renameVariables'
	hoistAssignments: require './hoistAssignments'




module.exports = new Parser