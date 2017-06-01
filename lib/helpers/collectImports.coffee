REGEX = require '../constants/regex'
helpers = require('./')

module.exports = collectImports = (tokens, lines)->
	@walkTokens tokens, lines, 'import', ()->
		output = helpers.newImportStatement('import')
		if @next().type is 'String'
			@prev()
		else
			throw @newError()

		while @next().type isnt 'String' then switch
			when @current.type is 'Punctuator'
				@handleMemebers(output)

			when @current.type is 'Identifier' and @current.value isnt 'from'
				@handleDefault(output)

		if @current.type is 'String'
			output.target = @current.value.removeAll(REGEX.quotes).trim()

		return output