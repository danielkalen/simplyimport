helpers = require('./')

module.exports = collectExports = (tokens, lines)->
	@walkTokens tokens, lines, 'export', ()->
		output = helpers.newExportStatement()
		@next()

		switch @current.type
			when 'Punctuator'
				@handleMemebers(output)
				@next() if @current.value is 'as'
				throw @newError() if @current.value isnt 'from' or @next().type isnt 'String'
				
				output.members = Object.invert(output.members) if output.members
				output.target = @current.value.removeAll(REGEX.quotes).trim()
			
			when 'Keyword'
				if @current.value is 'default'
					output.default = true
					@next()
				
				if @current.type is 'Keyword'
					output.keyword = @current.value
					@next()

				if @current.type is 'Identifier'
					output.identifier = @current.value
				else if @current.value isnt '='
					@prev()
					
			else throw @newError()

		return output

