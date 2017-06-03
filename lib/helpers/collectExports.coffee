REGEX = require '../constants/regex'
helpers = require('./')

module.exports = collectExports = (tokens, lines)->
	@walkTokens tokens, lines, 'export', ()->
		output = helpers.newExportStatement()
		@next()

		switch
			when @current.type.label is '{'
				@handleMemebers(output)
				@next() if @current.value is 'as'
				throw @newError() if @current.value isnt 'from' or @next().type.label isnt 'string'
				
				output.members = Object.invert(output.members) if output.members
				output.target = @current.value.removeAll(REGEX.quotes).trim()
			
			when @current.type.keyword
				if @current.value is 'default'
					output.default = true
					@next()
				
				if @current.type.keyword
					output.keyword = @current.value
					@next()

				if @current.type.label is 'name'
					output.identifier = @current.value
				else if @current.value isnt '='
					@prev()
					
			else throw @newError()

		return output

