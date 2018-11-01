parser = require '../external/parser'
helpers = require '../helpers'
templates = require '../templates'
REGEX = require '../constants/regex'
types = require 'ast-types'
n = types.namedTypes
b = require './builders'

exports.b = b
exports.n = n

exports.bundle = (task, files)->
	bundle = exports.bundler(task)
	{loader, modules} = exports.loader(task.options.target, task.options.loaderName)
	
	files.forEach (file)->
		modules.push exports.moduleProp(file, task.options.loaderName)

	bundle.body[0].expression.callee.object.expression.body.body.unshift(loader)
	return bundle


exports.bundler = (task)->
	loaderName = task.options.loaderName
	ARGS = [loaderName]
	VALUES = [if task.options.target is 'node' then "typeof require === 'function' && require" else "null"]
	BODY = switch
		when task.options.umd
			templates.umd.build(LOADER:loaderName, NAME:task.options.umd, ENTRY_ID:task.entryFile.IDstr)
		when task.options.returnLoader
			"return #{loaderName}"
		when task.options.returnExports
			"return module.exports = #{loaderName}(#{task.entryFile.IDstr})"
		else
			"return #{loaderName}(#{task.entryFile.IDstr})"
	
	if task.requiredGlobals.global
		ARGS.push 'global'
		VALUES.push templates.globalDec.build()
	
	return templates.iife.ast({ARGS, VALUES, BODY})


exports.loader = (target, loaderName)->
	targetLoader = if target is 'node' then 'loaderNode' else 'loaderBrowser'
	loader = templates[targetLoader].ast(LOADER:loaderName).body[0]
	modules = loader.expression.right.arguments[1].properties
	return {loader, modules}


exports.moduleProp = (file, loaderName)->
	b.property 'init', b.literal(file.ID), exports.moduleFn(file, loaderName)


exports.moduleFn = (file, loaderName)->
	body = moduleBody = []
	
	if file.requiredGlobals.__filename or file.requiredGlobals.__dirname
		ARGS = []; VALUES = []
		
		if file.requiredGlobals.__filename
			ARGS.push '__filename'
			VALUES.push "'/#{file.pathRel}'"
		
		if file.requiredGlobals.__dirname
			ARGS.push '__dirname'
			VALUES.push "'/#{file.contextRel}'"
		
		moduleBody.push wrapper = templates.iife.ast({ARGS, VALUES}).body[0]
		moduleBody = wrapper.expression.callee.object.expression.body.body

	file.ast = b.content(file.content) if not file.ast
	
	if n.Content.check(file.ast)
		moduleBody.push file.ast
		lastStatement = file.ast
	else
		moduleBody.push file.ast.body...
		lastStatement = file.ast.body[file.ast.body.length-1]

	unless n.ReturnStatement.check(lastStatement)
		body.push b.returnStatement b.propertyAccess('module', 'exports')

	b.functionExpression(
		null
		[b.identifier(loaderName), b.identifier('module'), b.identifier('exports')]
		b.blockStatement(body)
	)


exports.emptyObject = (statement)->
	b.objectExpression [
		b.property('init', b.identifier('empty'), b.literal(true))
	]


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



exports.import = (statement)->
	{target, source} = statement
	loader = source.task.options.loaderName
	renames = source.pendingMods.renames

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
					renames.push {source:b.identifier(statement.default), target:b.propertyAccess(alias, 'default')}
				else
					decs.push [statement.default, alias]

			if statement.specifiers
				for specifier in statement.specifiers
					{local, imported} = specifier
					local = b.identifier(local)
					imported = b.propertyAccess(alias, imported)
					if statement.isNested
						decs.push [local, imported]
					else
						renames.push {source:local, target:imported}

			ast = b.varDeclaration decs...


	return ast




exports.export = (statement)->
	{target, source} = statement
	loader = source.task.options.loaderName
	hoist = source.pendingMods.hoist

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
					assignment = b.assignmentStatement b.propertyAccess('exports',id), id
					ast = b.program [statement.dec]
					
					if n.FunctionDeclaration.check(statement.dec)
						hoist.push assignment
					else
						ast.body.push assignment


		when 'default'
			ast = b.program []
			dec = statement.dec
			property = b.propertyAccess('exports','default')
			switch
				when n.Expression.check(statement.dec)
					ast.body.push b.assignmentStatement property, dec
					
					if n.AssignmentExpression.check(dec) and not dec.right.id
						if n.FunctionExpression.check(dec.right) or n.ClassExpression.check(dec.right)
							statement.dec.right.id = dec.left

				when n.FunctionDeclaration.check(dec)
					if not dec.id
						dec.type = 'FunctionExpression'
						hoist.push b.assignmentStatement property, dec
					else
						ast.body.push dec
						hoist.push b.assignmentStatement property, dec.id

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


exportSpecifiers = (specifiers, target)->
	for specifier in specifiers
		{exported, local} = specifier
		local = if target then b.propertyAccess(target, local) else b.identifier(local)
		b.assignmentStatement b.propertyAccess('exports', exported), local





