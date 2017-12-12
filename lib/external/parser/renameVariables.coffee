types = require 'ast-types'
n = types.namedTypes

renameVariables = (ast, mappings)->
	types.visit ast,
		visitIdentifier: (path)->
			node = path.node
			mapping = matchMapping(node, mappings)
			return false if not mapping
			parent = path.parent.node

			if n.MemberExpression.check(parent)
				return false if parent.object isnt node

			if n.Property.check(parent)
				return false if parent.key is node

			if path.scope.depth > 0
				return false if !!path.scope.lookup(mapping.source.name)

			path.replace(mapping.target)

			return false


matchMapping = (node, mappings)->
	for entry in mappings
		return entry if entry.source.name is node.name
	return






module.exports = renameVariables