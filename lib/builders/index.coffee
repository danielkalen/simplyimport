Parser = require('../external/parser')
stringBuilders = require './strings'
b = require('ast-types').builders

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
	
	return Parser.parse stringBuilders.iife(args, values, body)

exports.loader = (target, loaderName)->
	targetLoader = if target is 'node' then 'loaderNode' else 'loaderBrowser'
	loader = Parser.parse(stringBuilders[targetLoader](loaderName)).body[0]
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
		
		moduleBody.push wrapper = Parser.parseExpr stringBuilders.iife(args, values)
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













