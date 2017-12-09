find = (ast, target)->
	result = []
	
	require('astw')(ast) (node)->
		result.push(node) if matchesTargets(node, target)

	return result


matchesTargets = (node, target)-> switch
	when typeof target is 'string'
		node.type.includes(target)
	
	when typeof target is 'function'
		target(node)
	
	when Array.isArray(target)
		target.some (target)-> node.type.includes(target)


module.exports = find