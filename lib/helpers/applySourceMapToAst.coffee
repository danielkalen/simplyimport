parser = require '../external/parser'
{SourceMapConsumer} = require 'source-map'

applySourceMapToAst = (ast, map)->
	map = new SourceMapConsumer(map)

	parser.walk ast, (node)->
		return if not node.loc
		origStart = map.originalPositionFor node.loc.start
		return node.loc = null if not origStart.line?
		origEnd = map.originalPositionFor node.loc.end

		node.loc.start = {line:origStart.line, column:origStart.column}
		node.loc.end = {line:origEnd.line, column:origEnd.column}
		node.loc.name = origStart.name if origStart.name
		node.loc.source ||= origStart.source


applySourceMapToAst = (ast, map)->
	map = new SourceMapConsumer(map)

	parser.walk ast, (node)->
		return if not node.loc
		{start, end} = node.loc
		end = start if end.line is null
		origStart = map.originalPositionFor start
		return node.loc = null if not origStart.line?
		origEnd = map.originalPositionFor end

		node.loc.start = {line:origStart.line, column:origStart.column}
		node.loc.end = {line:origEnd.line, column:origEnd.column}
		node.loc.name = origStart.name if origStart.name
		node.loc.source ||= origStart.source



module.exports = applySourceMapToAst