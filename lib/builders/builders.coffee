REGEX = require '../constants/regex'
b = require('ast-types').builders
B = exports
exports[key] = value for key,value of b

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





astify = exports.astify = (args...)->
	args.map (arg)-> switch
		when arg and arg.type? then arg
		when Array.isArray(arg) and arg[1] is 'id' then b.identifier(arg[0])
		when Array.isArray(arg) then b.arrayExpression(arg)
		when Object.isObject(arg) then b.objectExpression(properties arg)
		else b.literal(arg)
