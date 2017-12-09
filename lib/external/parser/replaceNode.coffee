walk = require './walk'

replaceNode = (ast, target, replacement)->
	parent = null
	walk ast, (node)->
		if property = isChildOf(target, node)
			parent ||= {node, property}

	if parent
		Object.set parent.node, parent.property, replacement

	return parent


isChildOf = (child, parent)->
	keys = Object.keys(parent)

	for key in keys
		value = parent[key]
		continue if typeof value isnt 'object' or not value

		if typeof value.type is 'string'
			return key if value is child
		
		else if typeof value.length is 'number' and value.length
			for item,index in value
				return "#{key}.#{index}" if item is child


module.exports = replaceNode