codegen = require 'astring'


codegen.baseGenerator.ParenthesizedExpression = (node, state)->
	state.write '('
	@[node.expression.type](node.expression, state)
	state.write ')'

codegen.baseGenerator.Content = (node, state)->
	state.write(node.content
		.split('\n')
		.map (line,index)-> if not index then line else state.indent.repeat(state.indentLevel)+line
		.join('\n')
	,node)

codegen.baseGenerator.ContentGroup = (node, state)->
	@[chunk.type](chunk, state) for chunk in node.body
	return

codegen.baseGenerator.ProgramContent = (node, state)->
	if state.indentLevel and node.content.type is 'Program'
		indent = state.indent.repeat(state.indentLevel)
		if state.output.endsWith(indent)
			state.output = state.output.slice(0,state.output.length-indent.length)
	
	@[node.content.type](node.content, state)


Object.keys(codegen.baseGenerator).forEach (method)->
	return if method is 'Identifier' or method is 'ContentGroup' or method.includes('Literal')
	fn = codegen.baseGenerator[method]
	codegen.baseGenerator[method] = (node, state)->
		state.write '', node if node.loc
		fn.call(@, node, state)

module.exports = codegen