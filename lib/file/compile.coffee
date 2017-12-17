stringPos = require 'string-pos'
helpers = require '../helpers'
parser = require '../external/parser'
debug = require('../debug')('simplyimport:file')
builders = require '../builders'
{b} = builders


exports.compile = ()->
	debug "compiling #{@pathDebug}"
	if not @has.ast
		@has.ast = true
		@ast = b.contentGroup []
		chunks = helpers.splitContentByStatements(@content, @statements)
		offset = index = 0
		
		for chunk in chunks
			if typeof chunk is 'string'
				node = b.content(chunk)
				node.loc = start:stringPos(@content, index-offset), source:@pathRel
			else
				node = b.content(chunk.replacement)
				node.loc = start:{column:0, line:1}, source:chunk.source.pathRel
				offset += node.content.length - (chunk.range.end - chunk.range.start)

			index += node.content.length
			@ast.body.push(node)
	
	else
		for statement in @statements
			Object.set statement.node.parent.node, statement.node.parent.key, statement.replacement
			statement.replacement.loc = statement.node.loc
			# console.log statement.replacement.loc.start, statement.replacement.type, statement.statementType if @isEntry

		if @pendingMods.renames.length
			parser.renameVariables @ast, @pendingMods.renames
		
		if @pendingMods.hoist.length
			parser.hoistAssignments @ast, @pendingMods.hoist


	if @task.options.sourceMap
		# if @inlineStatements.length
		# 	map = new (require 'source-map').SourceMapGenerator()

		if @sourceMaps.length
			helpers.applySourceMapToAst(@ast, map) for map in @sourceMaps.reverse()






