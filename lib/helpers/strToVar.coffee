REGEX = require '../constants/regex'
history = Object.create(null)

strToVar = (str)->
	result = "__"+str.replace(REGEX.varIncompatible, '')
	if history[str]
		return result+(++history[str])
	else
		history[str] = 1
		return result

module.exports = strToVar