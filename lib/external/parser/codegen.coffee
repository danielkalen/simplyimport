codegen = require 'astring'
# extend = require 'extend'
# defaults =
# 	comments: true
# 	indent: ''

# codegen.generate = do ()->
# 	orig = codegen.generate
# 	return (ast, opts)->
# 		orig ast, extend({}, defaults, opts)

codegen.baseGenerator.ParenthesizedExpression = (node, state)->
	state.write '('
	@[node.expression.type](node.expression, state)
	state.write ')'

codegen.baseGenerator.Content = (node, state)->
	state.write(node.content
		.split '\n'
		.map (line,index)-> if not index then line else state.indent.repeat(state.indentLevel)+line
		.join '\n'
	)

codegen.baseGenerator.ProgramContent = (node, state)->
	@[node.content.type](node.content, state)


module.exports = codegen