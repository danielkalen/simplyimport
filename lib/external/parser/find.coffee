find = (ast, targets)->
	targets = [targets] if typeof targets is 'string'
	result = []
	walk = require('astw')(ast)
	
	walk (node)->
		for target in targets
			return result.push(node) if node.type.includes(target)

	return result


module.exports = find