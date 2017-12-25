parser = require '../external/parser'
pos = require 'string-pos'


applyOffsetsSourceMap = (file)->
	{inlineStatements, offsets, original, content, ast} = file
	# content = file.contentPostInlinement

	parser.walk ast, (node)->
		return if not node.loc or not node.start?
		offset = offsetManual = 0

		for entry in offsets
			if isWithinOffset(node, entry)
				return node.loc = null

			if node.start > entry.pos
				offset += entry.length
				offsetManual = offset


		for statement in inlineStatements
			range = resolveStatementRange(statement, offsetManual)
			
			if isWithinRange(node, range, 0)
				newLoc = source:statement.target.pathRel, start:null, end:null
				newLoc.start = pos statement.replacement, pos.toIndex(content, node.loc.start)-range.start
				newLoc.end = pos statement.replacement, pos.toIndex(content, node.loc.end)-range.start
				node.loc = newLoc
				return
			
			else if containsRange(node, range, 0)
				break
			
			else if isBeforeRange(node, range, 0)
				break
			
			else
				offset += range.diff


		if offset
			node.start -= offset
			node.end -= offset		
			node.loc.start = pos(original.content, node.start)
			node.loc.end = pos(original.content, node.end)


containsRange = (node, range, offset)->
	node.start <= range.start+offset and node.end >= range.end+offset

isWithinRange = (node, range, offset)->
	node.start >= range.start+offset and node.end <= range.end+offset

isBeforeRange = (node, range, offset)->
	node.start < range.start+offset

isWithinOffset = (node, offset)->
	node.start >= offset.pos and node.end <= offset.pos+offset.length

resolveStatementRange = (statement, offsetManual)->
	range = statement.rangeNew
	if offsetManual
		return {start:range.start+offsetManual, end:range.end+offsetManual, diff:range.diff}
	return range

module.exports = applyOffsetsSourceMap