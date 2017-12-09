parser = require '../external/parser'
helpers = require '../helpers'
stringBuilders = require './strings'
REGEX = require '../constants/regex'
types = require 'ast-types'
n = types.namedTypes
b = types.builders
B = exports

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
		
		moduleBody.push wrapper = parser.parseExpr stringBuilders.iife(args, values)
		moduleBody = wrapper.callee.object.expression.body.body
	
	moduleBody.push b.content(file.content)
	body.push b.returnStatement b.memberExpression(b.identifier('module'), b.identifier('exports')) unless file.hasExplicitReturn

	body = body.map (node)->
		if node.type.includes('Statement') or node.type.includes('Declaration') then node else b.expressionStatement(node)

	b.functionExpression(
		null
		[b.identifier(loaderName), b.identifier('module'), b.identifier('exports')]
		b.blockStatement(body)
	)

exports.customDeclaration = (type, pairs...)->
	b.variableDeclaration type, pairs.map (pair)->
		B.varAssignment(pair[0], pair[1])

exports.varDeclaration = ()->
	B.customDeclaration 'var', arguments...

exports.varAssignment = (key, value)->
	[value] = astify(value) unless value is null
	key = b.identifier(key) if typeof key is 'string'
	b.variableDeclarator key, value

exports.assignment = (key, value, operator='=')->
	[value] = astify(value)
	key = b.identifier(key) if typeof key is 'string'
	b.assignmentExpression operator, key, value

exports.assignmentStatement = (key, value, operator)->
	b.expressionStatement B.assignment(key, value, operator)

exports.inExpression = (left, right)->
	[left, right] = astify(left, right)
	b.binaryExpression 'in', left, right

exports.andExpression = (left, right)->
	[left, right] = astify(left, right)
	b.logicalExpression '&&', left, right

exports.propertyAccess = (object, property, computed)->
	object = b.identifier(object) if typeof object is 'string'
	if typeof property is 'string'
		if REGEX.varCompatible.test(property)
			property = b.identifier(property)
		else
			property = b.literal(property)
			computed = true
	
	if computed?
		b.memberExpression object, property, computed
	else
		b.memberExpression object, property

exports.callExpression = (target, args...)->
	[target] = astify(target)
	args = args.map (arg)-> astify(arg)[0]
	b.callExpression target, args



exports.import = (statement, loader)->
	{target, source} = statement

	switch
		when statement.excluded
			ast = B.callExpression ['require','id'], target.ID or target
		
		when not statement.members and not statement.alias # commonJS import / side-effects es6 import
			ast = B.callExpression [loader,'id'], target.ID

			if statement.extract
				ast = B.propertyAccess ast, statement.extract
			
			else if target.hasDefaultExport and source.options.extractDefaults
				key = b.identifier helpers.strToVar(target.pathName)
				ast = b.parenthesizedExpression b.callExpression(
					b.functionExpression null, [], b.blockStatement [
						B.varDeclaration([key, ast])
						b.returnStatement b.conditionalExpression(
							B.andExpression(key, B.inExpression('default',key))
							B.propertyAccess(key, 'default')
							key
						)
					]
				,[])

		else
			alias = b.identifier statement.alias or helpers.strToVar(target.pathName)
			decs = []
			decs.push [alias, B.callExpression([loader,'id'], target.ID)]
			
			if statement.members
				nonDefault = Object.exclude(statement.members, (k,v)-> v is 'default')
				
				if statement.members.default
					if target.hasDefaultExport and source.options.extractDefaults
						decs.push [statement.members.default, B.propertyAccess(alias, 'default')]
					else
						decs.push [statement.members.default, alias]

				for key,keyAlias of nonDefault
					decs.push [keyAlias, B.propertyAccess(alias, key)]

			ast = B.varDeclaration(decs...)

	return parser.generate(ast)



exports.export = (statement, loader)->
	{target, source} = statement

	# if statement.nested
		# console.log statement.nested[0].statement.source.path
		# console.log statement.nested
	# 	for nested in statement.nested
	# 		statement.dec = 
	# 		targetDec = statement.decs[nested.dec]
	# 		targetDec.content =
	# 			targetDec.content.slice(0, nested.range.start) +
	# 			target.resolveStatementReplacement(nested.statement) +
	# 			targetDec.content.slice(nested.range.end)

	switch statement.exportType
		when 'all'
			alias = b.identifier helpers.strToVar(target.pathName)
			key = b.identifier '__tmp'
			ast = b.program [
				B.varDeclaration([alias, B.callExpression([loader,'id'], target.ID)])
				
				b.forInStatement key, alias, b.blockStatement [
					B.assignmentStatement B.propertyAccess('exports',key,true), B.propertyAccess(alias,key,true)
				]
			]

		when 'named-spec'
			if target is source
				ast = b.program exportSpecifiers(statement.specifiers)
			else
				alias = b.identifier helpers.strToVar(target.pathName)
				ast = b.program	[
					B.varDeclaration([alias, B.callExpression([loader,'id'], target.ID)])
					exportSpecifiers(statement.specifiers, alias)...
				]

		when 'named-dec'
			switch
				when target isnt source
					alias = b.identifier helpers.strToVar(target.pathName)
					ast = b.program [
						B.varDeclaration([alias, B.callExpression([loader,'id'], target.ID)])
						exportSpecifiers(statement.specifiers)...
					]
				
				when n.VariableDeclaration.check(statement.dec)
					ast = statement.dec
					for dec in statement.dec.declarations
						dec.init.id = dec.id if n.FunctionExpression.check(dec.init) and not dec.init.id
						dec.init = B.assignment B.propertyAccess('exports', dec.id.name), dec.init
				
				else
					id = statement.dec.id
					ast = b.program [
						statement.dec
						B.assignmentStatement B.propertyAccess('exports',id), id
					]


		when 'default'
			ast = b.program []
			dec = statement.dec
			property = B.propertyAccess('exports','default')
			switch
				when n.Expression.check(statement.dec)
					ast.body.push B.assignmentStatement property, dec
					
					if n.AssignmentExpression.check(dec) and not dec.right.id
						if n.FunctionExpression.check(dec.right) or n.ClassExpression.check(dec.right)
							statement.dec.right.id = ast.dec.left

				when n.FunctionDeclaration.check(dec)
					if not dec.id
						dec.type = 'FunctionExpression'
						ast.body.push B.assignmentStatement property, dec
					else
						ast.body.push dec
						ast.body.push B.assignmentStatement property, dec.id

				when n.ClassDeclaration.check(dec)
					dec.id ||= b.identifier '__class'
					ast.body.push dec
					ast.body.push B.assignmentStatement property, dec.id

				else
					ast.body.push B.assignmentStatement property, dec


	return parser.generate(ast)






astify = (args...)->
	args.map (arg)-> switch
		when arg and arg.type? then arg
		when Array.isArray(arg) and arg[1] is 'id' then b.identifier(arg[0])
		when Array.isArray(arg) then b.arrayExpression(arg)
		when Object.isObject(arg) then b.objectExpression(properties arg)
		else b.literal(arg)

properties = (obj)->
	Object.keys(obj).map (key)->
		b.property(
			'init'
			if REGEX.varCompatible.test(key) then b.identifier(key) else b.literal(key)
			astify(obj[key])[0]
		)


exportSpecifiers = (mapping, target)->
	for exported,local of mapping
		exported = if target then B.propertyAccess(target, exported) else b.identifier(exported)
		B.assignmentStatement B.propertyAccess('exports', local), exported





