parser = require '../external/parser'
helpers = require '../helpers'
stringBuilders = require './strings'
REGEX = require '../constants/regex'
types = require 'ast-types'
n = types.namedTypes
b = require './builders'

exports.b = b
exports.n = n

exports.bundle = (task)->
	loaderName = task.options.loaderName
	args = [loaderName]
	values = [if task.options.target is 'node' then "typeof require === 'function' && require" else "null"]
	body = switch
		when task.options.umd
			stringBuilders.umd(loaderName, task.options.umd, task.entryFile.IDstr)
		when task.options.returnLoader
			"return #{loaderName}"
		when task.options.returnExports
			"return module.exports = #{loaderName}(#{task.entryFile.IDstr})"
		else
			"return #{loaderName}(#{task.entryFile.IDstr})"
	
	if task.requiredGlobals.global
		args.push 'global'
		values.push stringBuilders.globalDec()
	
	return parser.parse stringBuilders.iife(args, values, body)

exports.loader = (target, loaderName)->
	targetLoader = if target is 'node' then 'loaderNode' else 'loaderBrowser'
	loader = parser.parse(stringBuilders[targetLoader](loaderName)).body[0]
	modules = loader.expression.right.arguments[1].properties
	return {loader, modules}


exports.moduleProp = (file, loaderName)->
	b.property 'init', b.literal(file.ID), exports.moduleFn(file, loaderName)


exports.moduleFn = (file, loaderName)->
	body = moduleBody = []
	
	if Object.keys(file.requiredGlobals).length
		args = []; values = []
		
		if file.requiredGlobals.__filename
			args.push '__filename'
			values.push "'/#{file.pathRel}'"
		
		if file.requiredGlobals.__dirname
			args.push '__dirname'
			values.push "'/#{file.contextRel}'"
		
		moduleBody.push wrapper = parser.parse(stringBuilders.iife(args, values)).body[0]
		moduleBody = wrapper.expression.callee.object.expression.body.body

	file.ast = b.content(file.content) if not file.ast
	
	if n.Content.check(file.ast)
		moduleBody.push file.ast
		lastStatement = file.ast
	else
		moduleBody.push file.ast.body...
		lastStatement = file.ast.body.last()

	unless n.ReturnStatement.check(lastStatement)
		body.push b.returnStatement b.propertyAccess('module', 'exports')

	b.functionExpression(
		null
		[b.identifier(loaderName), b.identifier('module'), b.identifier('exports')]
		b.blockStatement(body)
	)



exports.inlineImport = (statement)->
	{target, source} = statement
	lastChar = source.content[statement.range.end]
	needsWrapping = lastChar is '.' or lastChar is '('
	
	switch
		when statement.kind is 'excluded'
			return b.content ''
		
		when statement.extract
			ast = b.content target.extract(statement.extract) or '{}'

		when target.has.ast
			ast = b.programContent(target.ast)

		else
			ast = target.ast

	return if needsWrapping then b.parenthesizedExpression(ast) else ast



exports.import = (statement, loader)->
	{target, source} = statement

	switch statement.kind
		when 'excluded'
			ast = b.callExpression ['require','id'], target.ID or target
		
		when 'require'
			ast = b.callExpression [loader,'id'], target.ID
			
			if statement.extract
				ast = b.propertyAccess ast, statement.extract
			
			else if target.has.defaultExport and source.options.extractDefaults
				key = b.identifier helpers.strToVar(target.pathName)
				ast = b.parenthesizedExpression b.callExpression(
					b.functionExpression null, [], b.blockStatement [
						b.varDeclaration([key, ast])
						b.returnStatement b.conditionalExpression(
							b.andExpression(key, b.inExpression('default',key))
							b.propertyAccess(key, 'default')
							key
						)
					]
				,[])

		when 'named'
			module = b.callExpression [loader,'id'], target.ID
			alias = b.identifier statement.namespace or helpers.strToVar(target.pathName)
			decs = []
			decs.push [alias, module]

			if statement.default
				if target.has.defaultExport and source.options.extractDefaults
					decs.push [statement.default, b.propertyAccess(alias, 'default')]
				else
					decs.push [statement.default, alias]

			if statement.specifiers
				for imported,local of statement.specifiers
					decs.push [local, b.propertyAccess(alias, imported)]

			ast = b.varDeclaration decs...


	return ast




exports.export = (statement, loader)->
	{target, source} = statement

	if statement.nested
		for nested in statement.nested
			parser.replaceNode statement.dec, nested.node, target.resolveStatementReplacement(nested)

	switch statement.kind
		when 'all'
			alias = b.identifier helpers.strToVar(target.pathName)
			key = b.identifier '__tmp'
			ast = b.program [
				b.varDeclaration([alias, b.callExpression([loader,'id'], target.ID)])
				
				b.forInStatement key, alias, b.blockStatement [
					b.assignmentStatement b.propertyAccess('exports',key,true), b.propertyAccess(alias,key,true)
				]
			]

		when 'named-spec'
			if target is source
				ast = b.program exportSpecifiers(statement.specifiers)
			else
				alias = b.identifier helpers.strToVar(target.pathName)
				ast = b.program	[
					b.varDeclaration([alias, b.callExpression([loader,'id'], target.ID)])
					exportSpecifiers(statement.specifiers, alias)...
				]

		when 'named-dec'
			switch
				when target isnt source
					alias = b.identifier helpers.strToVar(target.pathName)
					ast = b.program [
						b.varDeclaration([alias, b.callExpression([loader,'id'], target.ID)])
						exportSpecifiers(statement.specifiers)...
					]
				
				when n.VariableDeclaration.check(statement.dec)
					ast = statement.dec
					for dec in statement.dec.declarations
						dec.init.id = dec.id if n.FunctionExpression.check(dec.init) and not dec.init.id
						dec.init = b.assignment b.propertyAccess('exports', dec.id.name), dec.init
				
				else
					id = statement.dec.id
					ast = b.program [
						statement.dec
						b.assignmentStatement b.propertyAccess('exports',id), id
					]


		when 'default'
			ast = b.program []
			dec = statement.dec
			property = b.propertyAccess('exports','default')
			switch
				when n.Expression.check(statement.dec)
					ast.body.push b.assignmentStatement property, dec
					
					if n.AssignmentExpression.check(dec) and not dec.right.id
						if n.FunctionExpression.check(dec.right) or n.ClassExpression.check(dec.right)
							statement.dec.right.id = ast.dec.left

				when n.FunctionDeclaration.check(dec)
					if not dec.id
						dec.type = 'FunctionExpression'
						ast.body.push b.assignmentStatement property, dec
					else
						ast.body.push dec
						ast.body.push b.assignmentStatement property, dec.id

				when n.ClassDeclaration.check(dec)
					dec.id ||= b.identifier '__class'
					ast.body.push dec
					ast.body.push b.assignmentStatement property, dec.id

				else
					ast.body.push b.assignmentStatement property, dec


	return b.programContent ast






properties = (obj)->
	Object.keys(obj).map (key)->
		b.property(
			'init'
			if REGEX.varCompatible.test(key) then b.identifier(key) else b.literal(key)
			b.astify(obj[key])[0]
		)


exportSpecifiers = (mapping, target)->
	for exported,local of mapping
		exported = if target then b.propertyAccess(target, exported) else b.identifier(exported)
		b.assignmentStatement b.propertyAccess('exports', local), exported





