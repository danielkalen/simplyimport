REGEX = require '../constants/regex'
helpers = require('./')
parser = require '../external/parser'

collectRequires = (file)->
	output = []
	nodes = file.statementNodes.filter(matchNode)

	for node in nodes
		output.push statement = helpers.newImportStatement()
		statement.kind = 'require'
		statement.node = node
		statement.target = helpers.normalizeTargetPath(node.arguments[0].value, file, true)
		statement.range.start = node.start
		statement.range.end = node.end

	return output


matchNode = (node)->
	node.type is 'CallExpression' and
	node.arguments.length is 1 and
	node.arguments[0].type is 'Literal' and
	typeof node.arguments[0].value is 'string' and (
		node.callee.name is 'require' or
		node.callee.name is '_$sm'
	)

module.exports = collectRequires
module.exports.match = matchNode