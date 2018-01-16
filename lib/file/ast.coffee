parser = require '../external/parser'
helpers = require '../helpers'
builders = require '../builders'
sourceMapConvert = require 'convert-source-map'
EXTENSIONS = require '../constants/extensions'
debug = require('../debug')('simplyimport:file')


exports.parse = ()->
	unless EXTENSIONS.nonJS.includes(@pathExt)
		@ast = @getAST() if @has.imports or @has.exports or @task.options.sourceMap
	
	if not @ast
		@ast = builders.b.content(@content)

	return


exports.getAST = (surpressErrors)->
	unless @has.ast
		@timeStart()
		debug "parsing #{@pathDebug}"
		try
			ast = parser.parse(@content, sourceFile:@pathRel, locations:@task.options.sourceMap)
		catch err
			if surpressErrors
				return @ast
			else
				@task.emit 'ASTParseError', @, err

		@ast = ast
		@has.ast = true
		@timeEnd()

	return @ast


exports.extractSourceMap = (content)->
	if map = sourceMapConvert.fromSource(content)?.sourcemap
		@sourceMaps.push(map)
		content = sourceMapConvert.removeComments(content)
		content = sourceMapConvert.removeMapFileComments(content)

	return content

	


exports.extract = (key, returnActual)->
	try
		@timeStart()
		@parsed ?= JSON.parse(@content)
		@timeEnd()
	catch err
		@task.emit 'DataParseError', @, err

	if not @parsed[key] and not Object.has(@parsed, key)
		@task.emit 'ExtractError', @, new Error "requested key '#{key}' not found"
	else
		result = @parsed[key] or Object.get(@parsed, key)
		return result if returnActual
		return JSON.stringify(result)


exports.exportLastExpression = (offset=0)->
	ast = @getAST(true)
	
	if not @has.ast
		@setContent "module.exports = #{ast.content}"
	
	else if last = ast.body[ast.body.length-1-offset]
		{b,n} = builders
		exportsNode = b.propertyAccess('module','exports')
		
		switch last.type			
			when 'ReturnStatement'
				if last.argument
					last.argument = b.assignment(exportsNode, last.argument)
				else
					return @exportLastExpression(offset+1)

			when 'ExpressionStatement'
				last.expression = b.assignment(exportsNode, last.expression)

			when 'FunctionDeclaration','ClassDeclaration'
				last.id ||= b.identifier(helpers.strToVar @pathName)
				ast.body.push b.assignmentStatement(exportsNode, last.id)
			
			when 'VariableDeclaration'
				ast.body.push b.assignmentStatement(exportsNode, last.declarations.slice(-1)[0].id)

			else
				return @exportLastExpression(offset+1)

	return
















