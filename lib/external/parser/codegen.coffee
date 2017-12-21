codegen = require 'astring'

# codegen.baseGenerator.Line = (node, state)->
# 	state.write "//#{node.value}"

# codegen.baseGenerator.Block = (node, state)->
# 	state.write '/*'
# 	state.write node.value
# 	state.write '*/'

codegen.baseGenerator.ParenthesizedExpression = (node, state)->
	state.write '('
	@[node.expression.type](node.expression, state)
	state.write ')'

codegen.baseGenerator.Content = (node, state)->
	extraLines = 0
	content = node.content
		.split '\n'
		.map (line, index)->
			if not index
				return line
			else
				extraLines += 1
				return state.indent.repeat(state.indentLevel)+line
		.join '\n'
	
	state.write(content, node)
	state.line += extraLines if state.sourceMap

codegen.baseGenerator.ContentGroup = (node, state)->
	@[chunk.type](chunk, state) for chunk in node.body
	return

codegen.baseGenerator.ProgramContent = (node, state)->
	if state.indentLevel and node.content.type is 'Program'
		indent = state.indent.repeat(state.indentLevel)
		if state.output.endsWith(indent)
			state.output = state.output.slice(0,state.output.length-indent.length)
	
	@[node.content.type](node.content, state)


skip = ['Identifier', 'ContentGroup']
Object.keys(codegen.baseGenerator).forEach (method)->
	return if skip.some((toSkip)-> method is toSkip) or method.includes('Literal')
	fn = codegen.baseGenerator[method]
	codegen.baseGenerator[method] = (node, state)->
		state.write '', node if node.loc
		fn.call(@, node, state)

module.exports = codegen