walk = (node, cb, parent)->
	cb(node, parent)
	
	unless isEndNode(node)
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
	node.type is 'Literal' or
	node.type is 'Identifier' or
	node.type is 'ThisExpression' or
	node.type is 'Super' or
	node.type is 'BreakStatement' or
	node.type is 'ContinueStatement' or
	node.type is 'DebuggerStatement' or
	node.type is 'EmptyStatement'




module.exports = walk