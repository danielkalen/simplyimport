REGEX = require '../constants/regex'
helpers = require('./')
parser = require '../external/parser'

# module.exports = collectRequires = (ast, content)->
# 	nodes = parser.find ast, (node)->
# 		node.type is 'CallExpression' and (
# 			node.callee.name is 'require' or
# 			node.callee.name is '_$sm'
# 		)

# 	for node in nodes
# 		output.push statement = helpers.newImportStatement('require')

module.exports = collectRequires = (tokens, content)->
	@walkTokens tokens, content, ['require','_$sm'], ()->
		@next()
		@next() if @current.value is '('
		return if @current.type.label isnt 'string'
		output = helpers.newImportStatement()
		output.target = @current.value.removeAll(REGEX.quotes).trim()

		return null if @next().value isnt ')'
		return output