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
	tokenize: (code, opts)-> Array.from acorn.tokenizer code, opts
	generate: (ast, opts)-> require('./codegen').generate ast, opts
	find: require './find'
	walk: require './walk'
	replaceNode: require './replaceNode'
	renameVariables: require './renameVariables'
	hoistAssignments: require './hoistAssignments'




module.exports = new Parser