parser = require '../external/parser'
helpers = require '../helpers'
builders = require '../builders'
EXTENSIONS = require '../constants/extensions'
debug = require('../debug')('simplyimport:file')


exports.parse = ()->
	unless EXTENSIONS.nonJS.includes(@pathExt) or (not @has.imports and not @has.exports)
		@ast = @getAST()
	
	if not @ast
		@ast = builders.b.content(@content)

	return


exports.getAST = (surpressErrors)->
	unless @has.ast
		@timeStart()
		debug "parsing #{@pathDebug}"
		try
			ast = parser.parseStrict(@content)
		catch err
			if surpressErrors
				return @ast
			else
				@task.emit 'ASTParseError', @, err

		@ast = ast
		@has.ast = true
		@timeEnd()

	return @ast


exports.genAST = ()->
	content = if @pathExt is 'json' then "(#{@content})" else @content
	@checkSyntaxErrors(content)
	try
		debug "generating AST #{@pathDebug}"
		@timeStart()
		@ast = parser.parse(content, range:true, loc:true, comment:true, source:@pathRel, sourceType:'module')
		@timeEnd()
	catch err
		@task.emit 'ASTParseError', @, err

	return content


exports.genSourceMap = ()->
	if @sourceMap
		return @sourceMap
	
	else if @ast
		@timeStart()
		@sourceMap = JSON.parse parser.generate(@ast, comment:true, sourceMap:true)
		@timeEnd()
		return @sourceMap


exports.adjustSourceMap = ()-> if @sourceMap
	return @sourceMap is @contentOriginal is @content
	output = require('inline-source-map')(file:@pathRel)
	mappings = require('combine-source-map/lib/mappings-from-map')(@sourceMap)
	currentOffset = 0
	


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
		ast.content = "module.exports = #{ast.content}"
	
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
















