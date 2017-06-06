REGEX = require '../constants/regex'
helpers = require('./')

module.exports = collectExports = (tokens, lines)->
	@walkTokens tokens, lines, 'export', ()->
		output = helpers.newExportStatement()
		@next()

		switch
			when @current.value is '{'
				@handleMemebers(output)
				output.members = Object.invert(output.members) if output.members
				
				@next() if @current.value is '}'

				if @current.value is 'from'
					throw @newError() if @next().type.label isnt 'string'
					output.target = @current.value.removeAll(REGEX.quotes).trim()
				else
					@prev()


			when @current.value is '*'
				throw @newError() if @next().value isnt 'from' or @next().type.label isnt 'string'
				output.target = @current.value.removeAll(REGEX.quotes).trim()

			
			when @current.type.keyword
				if @current.value is 'default'
					output.default = true
					@next()
				
				if @current.type.keyword # var|let|const|function|class
					output.keyword = @current.value
					if REGEX.decKeyword.test(output.keyword) # var|let|const
						@storeDecs(output.decs = Object.create(null))
						return output

					@next()


				if @current.type.label is 'name' # function-name|class-name|assignment-expr-left 
					output.identifier = @current.value
					if not output.keyword # assignment-expr
						@next().end++ # will be the '=' punctuator
				
				else if @current.value isnt '=' # funciton-args-start|class-block-start
					@prev()

			else throw @newError()

		return output

