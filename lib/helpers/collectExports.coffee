REGEX = require '../constants/regex'
helpers = require('./')
parser = require '../external/parser'

collectExports = (ast, file)->
	output = []
	nodes = parser.find ast, ['ExportNamedDeclaration', 'ExportDefaultDeclaration', 'ExportAllDeclaration']

	for node in nodes
		output.push statement = helpers.newExportStatement()
		statement.range.start = node.start
		statement.range.end = node.end
		
		switch node.type
			when 'ExportAllDeclaration'
				statement.exportType = 'all'
				statement.target = helpers.normalizeTargetPath(node.source.value, file, true)

			when 'ExportDefaultDeclaration'
				statement.exportType = 'default'
				statement.dec = objectWithout node.declaration, 'parent'

			when 'ExportNamedDeclaration'
				if node.declaration
					statement.exportType = 'named-dec'
					statement.dec = objectWithout node.declaration, 'parent'
				else
					statement.exportType = 'named-spec'
					statement.target = helpers.normalizeTargetPath(node.source.value, file, true) if node.source
					statement.specifiers = Object.create(null)
					for specifier in node.specifiers
						statement.specifiers[specifier.local.name] = specifier.exported.name

	return output


objectWithout = (object, exclude)->
	output = Object.create(null)

	for key in Object.keys(object) when key isnt exclude
		output[key] = object[key]
	
	return output


module.exports = collectExports#.memoize (tokens, content, importer)-> "#{importer.path}/#{content}"
