Parser = require '../external/parser'
EXTENSIONS = require '../constants/extensions'

module.exports = exportLastExpression = (file)->
	return file.content if EXTENSIONS.static.includes(file.pathExt)
	ast = try Parser.parseStrict(file.contentSafe, range:true)
	
	if not ast
		return content:"module.exports = #{file.content}", offset:[0,17]
	
	else if ast.body.length
		last = ast.body.last()
		
		insertExport = (pos)->
			newContent = file.content.insert 'module.exports = ', pos
			return content:newContent, offset:[pos,pos+17]
		
		switch last.type
			when 'ThrowStatement'
				return content:file.content
			
			when 'Literal','Identifier','ClassDeclaration','FunctionDeclaration'
				return insertExport(last.start)

			when 'VariableDeclaration'
				last = last.declarations.slice(-1)[0]
				return content:"#{file.content}\nmodule.exports = #{last.id.name}"

			when 'ReturnStatement'
				file.hasExplicitReturn = true
				return content:file.content if not last.argument
				return insertExport(last.argument.start)

			else
				if last.type.includes 'Expression'
					return insertExport(last.start)
				
				find = require 'scrumpy'
				decs = find ast, type:'VariableDeclarator'
				assigns = find ast, type:'AssignmentExpression'
				funcs = find ast, type:'FunctionDeclaration'
				decs = decs.concat assigns, funcs

				break if decs.length is 0
				
				lastDec = decs.max('start')
				id = switch lastDec.type
					when 'VariableDeclarator','FunctionDeclaration'
						lastDec.id.name
					else # when 'AssignmentExpression'
						lastDec.left.name

				return content:"#{file.content}\nmodule.exports = #{id}"
	

	return content:file.content





