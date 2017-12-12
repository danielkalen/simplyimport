REGEX = require '../constants/regex'
helpers = require('./')
parser = require '../external/parser'

module.exports = collectImports = (ast, file)->
	output = []
	nodes = parser.find ast, 'ImportDeclaration'

	for node in nodes
		output.push statement = helpers.newImportStatement()
		statement.kind = 'named'
		statement.node = node
		statement.target = helpers.normalizeTargetPath(node.source.value, file, true)
		statement.range.start = node.start
		statement.range.end = node.end

		for specifier in node.specifiers then switch specifier.type
			when 'ImportNamespaceSpecifier'
				statement.namespace = specifier.local.name

			when 'ImportDefaultSpecifier'
				statement.default = specifier.local.name

			when 'ImportSpecifier'
				statement.specifiers ||= []
				statement.specifiers.push local:specifier.local.name, imported:specifier.imported.name

	return output