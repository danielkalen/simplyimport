TokenWalker = require './tokenWalker'

module.exports = walkTokens = (tokens, content, valueToStopAt, cb)->
	walker = new TokenWalker(tokens, content, cb)
	
	for token,i in tokens when (if valueToStopAt? then token.value is valueToStopAt else true)
		walker.invoke(token, i)
	
	return walker.finish()