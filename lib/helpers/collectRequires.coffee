REGEX = require '../constants/regex'
helpers = require('./')

module.exports = collectRequires = (tokens, content)->
	@walkTokens tokens, content, 'require', ()->
		@next()
		@next() if @current.value is '('
		return if @current.type.label isnt 'string'
		output = helpers.newImportStatement()
		output.target = @current.value.removeAll(REGEX.quotes).trim()

		return null if @next().value isnt ')'
		return output