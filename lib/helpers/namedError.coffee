cache = Object.create(null)

module.exports = (targetName, noStack)->
	if cache[targetName]
		return cache[targetName]
	else
		# newErrorCtor = ()->
		# 	Error.call(@)
		# 	if noStack then delete @stack
		# 	return @
		# ctor = ()-> @constructor = newErrorCtor; @
		# ctor:: = Error::
		# newErrorCtor:: = new ctor()
		# Object.defineProperty newErrorCtor, 'name', value: targetName
		# Object.defineProperty newErrorCtor::, 'name', value: targetName
		# console.log (new newErrorCtor('mas')) instanceof Error
		# console.log new ctor
		# require('util').inherits(newErrorCtor, Error)
		
		# class CustomError extends Error
		# 	name: targetName
		# 	constructor: ()-> super

		CustomError = (message)->
			@name = targetName
			@message = message or ''
			@stack = if noStack then '' else (new Error).stack

		CustomError:: = new Error
		Object.defineProperty CustomError, 'name', value: targetName
		Object.defineProperty CustomError::, 'name', value: targetName

		return cache[targetName] = CustomError