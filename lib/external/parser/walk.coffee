walk = (node, cb, parent)->
	keys = Object.keys(node)

	for key in keys
		value = node[key]
		continue if typeof value isnt 'object' or not value

		if typeof value.type is 'string'
			walk(value, cb, {node, property:key})
		
		else if typeof value.length is 'number' and value.length
			for item,index in value
				if item and typeof item.type is 'string'
					walk(item, cb, {node, property:"#{key}.#{index}"})

	cb(node, parent)





module.exports = walk