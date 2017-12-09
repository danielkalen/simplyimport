REGEX = require '../constants/regex'
helpers = require('./')
parser = require '../external/parser'

collectExports = (ast, file)->
	output = []
	nodes = parser.find ast, ['ExportNamedDeclaration', 'ExportDefaultDeclaration', 'ExportAllDeclaration']

	for node in nodes
		output.push statement = helpers.newExportStatement()
		statement.node = node
		statement.range.start = node.start
		statement.range.end = node.end
		
		switch node.type
			when 'ExportAllDeclaration'
				statement.kind = 'all'
				statement.target = helpers.normalizeTargetPath(node.source.value, file, true)

			when 'ExportDefaultDeclaration'
				statement.kind = 'default'
				statement.dec = node.declaration

			when 'ExportNamedDeclaration'
				if node.declaration
					statement.kind = 'named-dec'
					statement.dec = node.declaration
				else
					statement.kind = 'named-spec'
					statement.target = helpers.normalizeTargetPath(node.source.value, file, true) if node.source
					statement.specifiers = Object.create(null)
					for specifier in node.specifiers
						statement.specifiers[specifier.local.name] = specifier.exported.name

	return output


module.exports = collectExports#.memoize (tokens, content, importer)-> "#{importer.path}/#{content}"
