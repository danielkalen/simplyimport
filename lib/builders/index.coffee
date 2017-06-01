Parser = require('../external/parser')
stringBuilders = require './strings'
b = require('ast-types').builders

exports.bundle = (task)->
	body = if task.options.umd then stringBuilders.umd(task.options.umd) else "return _s$m(#{task.entryFile.IDstr})"
	args = ['_s$m']; values = ['null']
	
	if task.requiredGlobals.global
		args.push 'global'
		values.push stringBuilders.globalDec()
	
	return Parser.parse stringBuilders.iife(args, values, body)

exports.loader = ()->
	loader = Parser.parse(stringBuilders.loader()).body[0]
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
			values.push file.pathRel
		
		if file.requiredGlobals.__dirname
			args.push '__dirname'
			values.push file.contextRel
		
		moduleBody.push wrapper = Parser.parseExpr stringBuilders.iife(args, values)
		moduleBody = wrapper.callee.object.body.body
	
	moduleBody.push file.AST.body...
	body.push b.returnStatement b.memberExpression(b.identifier('module'), b.identifier('exports'))
	return b.functionExpression null, [b.identifier('module'), b.identifier('exports')], b.blockStatement(body)













