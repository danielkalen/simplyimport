REGEX = require '../constants/regex'
helpers = require('./')
parser = require '../external/parser'

collectExports = (tokens, content, importer)->
	@walkTokens tokens, content, 'export', ()->
		return if @current.type.keyword isnt 'export'
		output = helpers.newExportStatement()
		@next()

		switch
			when @current.value is '{'
				@handleMemebers(output)
				output.members = Object.invert(output.members) if output.members
				
				@next() if @current.value is '}'

				if @current.value is 'from'
					throw @newError() if @next().type.label isnt 'string'
					output.target = helpers.normalizeTargetPath(@current.value, importer, true)
				else
					@prev()


			when @current.value is '*'
				throw @newError() if @next().value isnt 'from' or @next().type.label isnt 'string'
				output.target = helpers.normalizeTargetPath(@current.value, importer, true)

			
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
					while @next().type.label and @current.value is '.' or @current.type.label is 'name'
						output.identifier += @current.value
														
				@prev()


			else throw @newError()

		return output


module.exports = collectExports#.memoize (tokens, content, importer)-> "#{importer.path}/#{content}"
