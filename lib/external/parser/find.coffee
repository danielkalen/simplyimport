walk = require './walk'

find = (ast, filter)->
	result = []
	
	walk ast, (node, parent)->
		if filter(node)
			node.parent = parent
			result.push(node)

	return result


module.exports = find