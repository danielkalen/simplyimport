Parser = require '../external/parser'

tokenize = (content)->
	try
		tokens = Parser.tokenize(content, range:true, sourceType:'module')
	catch err
		return err

	tokens.forEach (token, index)-> token.index = index
	return tokens


module.exports = tokenize.memoize()