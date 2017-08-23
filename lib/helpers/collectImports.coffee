REGEX = require '../constants/regex'
helpers = require('./')

module.exports = collectImports = (tokens, content)->
	@walkTokens tokens, content, 'import', ()->
		output = helpers.newImportStatement('import')
		if @next().type.keyword
			throw @newError()
		else
			@prev()

		while @next().type.label isnt 'string' then switch
			when @current.value is '{' or @current.value is '*'
				@handleMemebers(output)

			when @current.type.label is 'name' and @current.value isnt 'from'
				@handleDefault(output)

		if @current.type.label is 'string'
			output.target = @current.value.removeAll(REGEX.quotes).trim()

		return output