parser = require '../external/parser'
pos = require 'string-pos'


applyForceInlineSourceMap = (file)->
	{inlineStatements, original, ast} = file
	content = file.contentPostInlinement

	parser.walk ast, (node)->
		return if not node.loc or not node.start?
		offset = 0

		for statement in inlineStatements
			range = statement.rangeNew
			
			if isWithinRange(node, range, offset)
				newLoc = source:statement.target.pathRel, start:null, end:null
				newLoc.start = pos statement.replacement, pos.toIndex(content, node.loc.start)-range.start
				newLoc.end = pos statement.replacement, pos.toIndex(content, node.loc.end)-range.start
				node.loc = newLoc
				return
			
			else if containsRange(node, range, offset)
				return
			
			else if isBeforeRange(node, statement.rangeNew, offset)
				break
			
			else
				offset += range.diff


		if offset
			node.start -= offset
			node.end -= offset
			node.loc.start = pos(original.content, node.start)
			node.loc.end = pos(original.content, node.end)


containsRange = (node, range, offset)->
	node.start <= range.start and node.end >= range.end

isWithinRange = (node, range, offset)->
	node.start >= range.start and node.end <= range.end

isBeforeRange = (node, range, offset)->
	node.start < range.start


module.exports = applyForceInlineSourceMap