walk = (node, cb, parent)->
	result = cb(node, parent)
	
	unless isEndNode(node) or result is false
		keys = Object.keys(node)

		for key in keys
			value = node[key]
			continue if typeof value isnt 'object' or not value

			if typeof value.type is 'string'
				walk(value, cb, {node, key})
			
			else if typeof value.length is 'number' and value.length
				for item,index in value
					if item and typeof item.type is 'string'
						walk(item, cb, {node, key:"#{key}.#{index}"})

	return

isEndNode = (node)->
	type = node.type
	type is 'Literal' or
	type is 'Identifier' or
	type is 'ThisExpression' or
	type is 'Super' or
	type is 'BreakStatement' or
	type is 'ContinueStatement' or
	type is 'DebuggerStatement' or
	type is 'EmptyStatement'




module.exports = walk