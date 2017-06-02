cache = Object.create(null)

module.exports = (targetName, noStack)->
	if cache[targetName]
		return cache[targetName]
	else
		newErrorCtor = ()-> Error.apply(@, arguments); if noStack then delete @stack; @
		ctor = ()-> @constructor = newErrorCtor
		ctor:: = Error::
		newErrorCtor:: = new ctor()
		Object.defineProperty newErrorCtor, 'name', value: targetName
		Object.defineProperty newErrorCtor::, 'name', value: targetName
		return cache[targetName] = newErrorCtor