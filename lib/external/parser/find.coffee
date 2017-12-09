walk = require './walk'

find = (ast, target)->
	result = []
	
	walk ast, (node)->
		result.push(node) if matchesTarget(node, target)

	return result


matchesTarget = (node, target)-> switch
	when typeof target is 'string'
		node.type.includes(target)
	
	when typeof target is 'function'
		target(node)
	
	when Array.isArray(target)
		target.some (target)-> node.type.includes(target)


module.exports = find