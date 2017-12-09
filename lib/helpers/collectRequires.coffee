REGEX = require '../constants/regex'
helpers = require('./')
parser = require '../external/parser'
n = require('ast-types').namedTypes

module.exports = collectRequires = (ast, file)->
	output = []
	nodes = parser.find ast, matchNode

	for node in nodes
		output.push statement = helpers.newImportStatement()
		statement.kind = 'require'
		statement.node = node
		statement.target = helpers.normalizeTargetPath(node.arguments[0].value, file, true)
		statement.range.start = node.start
		statement.range.end = node.end

	return output


matchNode = (node)->	
	n.CallExpression.check(node) and
	node.arguments.length is 1 and
	n.Literal.check(node.arguments[0]) and
	typeof node.arguments[0].value is 'string' and (
		node.callee.name is 'require' or
		node.callee.name is '_$sm'
	)