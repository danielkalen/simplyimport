Parser = require('../external/parser')
stringBuilders = require './strings'
b = require('ast-types').builders

exports.bundle = (task)->
	args = ['require']
	values = [if task.options.target is 'node' then "typeof require === 'function' && require" else "null"]
	body = switch
		when task.options.umd
			stringBuilders.umd(task.options.umd, task.entryFile.idstr)
		when task.options.returnLoader
			"return require"
		else
			"return require(#{task.entryFile.IDstr})"
	
	if task.requiredGlobals.global
		args.push 'global'
		values.push stringBuilders.globalDec()
	
	return Parser.parse stringBuilders.iife(args, values, body)

exports.loader = (target)->
	targetLoader = if target is 'node' then 'loaderNode' else 'loaderBrowser'
	loader = Parser.parse(stringBuilders[targetLoader]()).body[0]
	modules = loader.expression.right.arguments[1].properties
	return {loader, modules}


exports.moduleProp = (file)->
	b.property 'init', b.literal(file.ID), exports.moduleFn(file)


exports.moduleFn = (file)->
	body = moduleBody = []
	
	if Object.keys(file.requiredGlobals).length
		args = []; values = []
		
		if file.requiredGlobals.__filename
			args.push '__filename'
			values.push "'/#{file.pathRel}'"
		
		if file.requiredGlobals.__dirname
			args.push '__dirname'
			values.push "'/#{file.contextRel}'"
		
		moduleBody.push wrapper = Parser.parseExpr stringBuilders.iife(args, values)
		moduleBody = wrapper.callee.object.expression.body.body
	
	moduleBody.push b.content(file.content)
	body.push b.returnStatement b.memberExpression(b.identifier('module'), b.identifier('exports')) unless file.hasExplicitReturn

	body = body.map (node)->
		if node.type.includes('Statement') or node.type.includes('Declaration') then node else b.expressionStatement(node)

	b.functionExpression(
		null
		[b.identifier('require'), b.identifier('module'), b.identifier('exports')]
		b.blockStatement(body)
	)













