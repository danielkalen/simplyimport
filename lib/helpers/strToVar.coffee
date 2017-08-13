REGEX = require '../constants/regex'

strToVar = (str)->
	"__"+str.replace(REGEX.varIncompatible, '')

module.exports = strToVar.memoize()