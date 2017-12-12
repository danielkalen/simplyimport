REGEX = require '../constants/regex'
helpers = require('./')
parser = require '../external/parser'

collectExports = (file)->
	output = []
	nodes = file.statementNodes.filter(matchNode)

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
					statement.specifiers = []
					for specifier in node.specifiers
						statement.specifiers.push {local:specifier.local.name, exported:specifier.exported.name}

	return output

matchNode = (node)->
	node.type is 'ExportNamedDeclaration' or
	node.type is 'ExportDefaultDeclaration' or
	node.type is 'ExportAllDeclaration'

module.exports = collectExports
module.exports.match = matchNode