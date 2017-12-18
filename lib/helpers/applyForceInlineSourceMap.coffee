parser = require '../external/parser'
pos = require 'string-pos'


applyForceInlineSourceMap = (file)->
	{inlineStatements, original, ast} = file
	content = file.contentPostInlinement

	parser.walk ast, (node)->
		return if not node.loc or not node.start?
		offset = 0

		for statement in inlineStatements
			if isWithinRange(node, statement, offset)
				base = pos(content, statement.range.start)
				newLoc = source:statement.target.pathRel, start:null, end:null
				newLoc.start = pos statement.replacement, pos.toIndex(content, node.loc.start)-statement.range.start
				newLoc.end = pos statement.replacement, pos.toIndex(content, node.loc.end)-statement.range.start
				# console.log parser.generate(node)
				# console.log newLoc.start, newLoc.end
				node.loc = newLoc
				return
			
			else if isBeforeRange(node, statement, offset)
				break
			else
				offset += statement.range.length

		
		if offset
			# if node.start is 0
			# 	console.log isBeforeRange(node, inlineStatements[0], 0), node.start, inlineStatements[0].range.start, inlineStatements[0].offset
				# console.dir node, depth:0, colors:1
			# if parser.generate(node).startsWith('function (a, b)')
			# 	console.log node.start, node.end, statement.range.start, statement.range.end #isWithinRange(node, inlineStatements[0], offset)
			node.start -= offset
			node.end -= offset
			node.loc.start = pos(content, node.start)
			node.loc.end = pos(content, node.end)
			# console.log node.loc.start
			# console.log parser.generate(node) if node.type is 'ExpressionStatement'


isWithinRange = (node, statement, offset)->
	start = statement.range.start+statement.offset
	end = statement.range.end+statement.offset
	node.start-offset >= start and node.end-offset <= end

isBeforeRange = (node, statement, offset)->
	start = statement.range.start+statement.offset
	node.start-offset < start


module.exports = applyForceInlineSourceMap