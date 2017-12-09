walk = (node, cb)->
	keys = Object.keys(node)

	for key in keys
		value = node[key]
		continue if typeof value isnt 'object' or not value

		if typeof value.type is 'string'
			walk(value, cb)
		
		else if typeof value.length is 'number' and value.length
			for item in value
				walk(item, cb) if item and typeof item.type is 'string'

	cb(node)

# walk = (node, cb, attachParent)->
# 	keys = Object.keys(node)

# 	for key in keys
# 		value = node[key]
# 		continue if typeof value isnt 'object' or not value or key is 'parent'

# 		if typeof value.type is 'string'
# 			value.parent = node if attachParent
# 			walk(value, cb)
		
# 		else if typeof value.length is 'number' and value.length
# 			for item in value
# 				if item and typeof item.type is 'string'
# 					item.parent = node if attachParent
# 					walk(item, cb)

# 	cb(node)




module.exports = walk