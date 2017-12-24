codegen = require './codegen'
extend = require 'extend'
acorn = require 'acorn'
require './customDef'


class Parser
	opts: (opts)-> extend({}, require('./acornOpts'), opts)
	parse: (code, opts)-> acorn.parse code, @opts(opts)
	generate: (ast, opts)-> require('./codegen').generate ast, opts
	find: require './find'
	walk: require './walk'
	replaceNode: require './replaceNode'
	renameVariables: require './renameVariables'
	hoistAssignments: require './hoistAssignments'




module.exports = new Parser