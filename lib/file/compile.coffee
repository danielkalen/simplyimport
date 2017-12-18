stringPos = require 'string-pos'
helpers = require '../helpers'
parser = require '../external/parser'
debug = require('../debug')('simplyimport:file')
{b} = require '../builders'
LOC_FIRST = {line:1, column:0}


exports.compile = ()->
	debug "compiling #{@pathDebug}"
	if not @has.ast
		@replaceStatementsWithoutAST()
	else
		@replaceStatementsWithAST()

		if @pendingMods.renames.length
			parser.renameVariables @ast, @pendingMods.renames
		
		if @pendingMods.hoist.length
			parser.hoistAssignments @ast, @pendingMods.hoist



	if @task.options.sourceMap
		debug "applying source maps #{@pathDebug}"
		if @sourceMaps.length
			helpers.applySourceMapToAst(@ast, map) for map in @sourceMaps.reverse()

		if @inlineStatements.length
			helpers.applyForceInlineSourceMap(@)



exports.replaceStatementsWithoutAST = ()->
	@has.ast = true
	@ast = b.contentGroup []
	chunks = helpers.splitContentByStatements(@content, @statements)
	offset = index = 0
	
	for chunk in chunks
		if typeof chunk is 'string'
			node = b.content(chunk)
			node.loc = newLoc @pathRel, stringPos(@content, index-offset)
		else
			node = b.content(chunk.replacement)
			node.loc = newLoc chunk.source.pathRel
			offset += node.content.length - (chunk.range.end - chunk.range.start)

		index += node.content.length
		@ast.body.push(node)
	return


exports.replaceStatementsWithAST = ()->
	for statement in @statements
		Object.set statement.node.parent.node, statement.node.parent.key, statement.replacement
		
		statement.replacement.start = statement.node.start
		statement.replacement.end = statement.node.end
		
		if statement.type isnt 'inline'
			statement.replacement.loc = statement.node.loc
		else
			statement.replacement.loc = newLoc statement.target.pathRel

	return


newLoc = (source, start, end)->
	source: source
	start: start or LOC_FIRST
	end: end or start or LOC_FIRST

