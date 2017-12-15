helpers = require '../helpers'
parser = require '../external/parser'
debug = require('../debug')('simplyimport:file')

exports.compile = ()->
	if not @has.ast
		split = helpers.splitContentByStatements(@content, @statements)
		@setContent split.reduce (acc, statement)=>
			return acc+statement if typeof statement is 'string'
			# @sourceMap.addRange {from:statement.range, to:newRange, name:"#{statement.statementType}:#{index+1}", content}
			return acc+statement.replacement

	else
		for statement in @statements
			Object.set statement.node.parent.node, statement.node.parent.key, statement.replacement
		
	if @pendingMods.renames.length
		parser.renameVariables @ast, @pendingMods.renames
	
	if @pendingMods.hoist.length
		parser.hoistAssignments @ast, @pendingMods.hoist









