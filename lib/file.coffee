Promise = require 'bluebird'
promiseBreak = require 'p-break'
replaceAsync = require 'string-replace-async'
streamify = require 'streamify-string'
getStream = require 'get-stream'
PATH = require 'path'
md5 = require 'md5'
chalk = require 'chalk'
extend = require 'extend'
Parser = require 'esprima'
LinesAndColumns = require 'lines-and-columns'
sourcemapConvert = require 'convert-source-map'
sourcemapRegex = sourcemapConvert.commentRegex
helpers = require './helpers'
REGEX = require './constants/regex'
EXTENSIONS = require './constants/extensions'


class File
	constructor: (@task, state)->
		extend(@, state)
		@ID = ++@task.currentID
		@exportStatements = []
		@importStatements = []
		@replacedRanges = imports:[], exports:[], inlines:[]
		# @badImports = []
		# @importMemberRefs = []
		# @lineRefs = []
		# @orderRefs = []
		@ignoreRanges = []
		@requiredGlobals = Object.create(null)
		@fileExtOriginal = @fileExt
		@contentOriginal = @content
		@options.transform ?= []
		
		if @isEntry or @isExternalEntry
			
			if  @pkgTransform = @pkgFile.browserify?.transform
				@pkgTransform = [@pkgTransform] if helpers.isValidTransformerArray(@pkgTransform)


		return @task.cache[@filePath] = @task.cache[@hash] = @



	checkIfIsThirdPartyBundle: ()->
		### istanbul ignore next ###
		@isThirdPartyBundle =
			@content.includes('.code="MODULE_NOT_FOUND"') or
			@content.includes('__webpack_require__') or
			@content.includes('System.register') or 
			@content.includes("' has not been defined'") or
			REGEX.moduleCheck.test(@content) or
			REGEX.defineCheck.test(@content) or
			REGEX.requireCheck.test(@content)

		@hasThirdPartyRequire = @isThirdPartyBundle and
			not REGEX.requireArg.test(@content) and
			REGEX.commonImportReal.test(@content)


	collectRequiredGlobals: ()-> if not @isThirdPartyBundle
		@task.emit('requiredGlobal',@,'global') if REGEX.vars.global.test(@content) and not REGEX.globalCheck.test(@content)
		@task.emit('requiredGlobal',@,'process') if REGEX.vars.process.test(@content) and not REGEX.processRequire.test(@content) and not REGEX.processDec.test(@content)
		@task.emit('requiredGlobal',@,'__dirname') if REGEX.vars.__dirname.test(@content)
		@task.emit('requiredGlobal',@,'__filename') if REGEX.vars.__filename.test(@content)
		return


	collectIgnoreRanges: ()-> if @options.scan isnt false
		currentRange = null
		@content.replace REGEX.ignoreStatement, (m, charIndex)=>
			if currentRange
				currentRange.end = charIndex
				@ignoreRanges.push(currentRange)
				currentRange = null
			else
				currentRange = start:charIndex
			return
		
		if currentRange
			currentRange.end = @content.length
			@ignoreRanges.push(currentRange)


	saveContent: (content)->
		@content = content

	saveContentMilestone: (milestone)->
		if @task.options.debug
			@[milestone] = @content
		else
			@content


	determineType: ()->
		@type = switch
			when @isEntry then 'module'
			when not REGEX.es6export.test(@content) and not REGEX.commonExport.test(@content) then 'inline'
			else 'module'

		@isDataType = true if EXTENSIONS.data.includes(@fileExt)


	applyAllTransforms: (content=@content)->
		@allTransforms = [].concat @options.transform, @task.options.globalTransform#, @pkgTransform
		Promise.resolve(content).bind(@)
			.then @applySpecificTransforms
			.then(@applyPkgTransforms if @isEntry or @isExternalEntry)
			.then(@applyGlobalTransforms unless @isEntry)


	applySpecificTransforms: (content)->
		Promise.resolve(content).bind(@)
			.then (content)->
				transforms = @options.transform
				forceTransform = switch
					when @fileExt is 'ts'		and not @allTransforms.includes('tsify') 		then 'tsify'
					when @fileExt is 'coffee'	and not @allTransforms.includes('coffeeify')	then 'coffeeify'
					when @fileExt is 'cson'		and not @allTransforms.includes('csonify') 		then 'csonify'
					when @fileExt is 'yml'		and not @allTransforms.includes('yamlify') 		then 'yamlify'
				
				transforms.unshift(forceTransform) if forceTransform
				promiseBreak(content) if not transforms.length
				return [content, transforms]
			
			.spread (content, transforms)->
				@applyTransforms(content, transforms, PATH.resolve(@pkgFile.dirPath,'node_modules'))

			.catch promiseBreak.end


	applyPkgTransforms: (content)->
		Promise.resolve(@pkgTransform).bind(@)
			.tap (transform)-> promiseBreak(content) if not transform
			.filter (transform)->
				name = if typeof transform is 'string' then transform else transform[0]
				return name.toLowerCase() isnt 'simplyimportify'
			
			.then (transforms)-> [content, transforms]
			.spread (content, transforms)->
				@applyTransforms(content, transforms, PATH.resolve(@pkgFile.dirPath,'node_modules'))

			.catch promiseBreak.end


	applyGlobalTransforms: (content)->
		Promise.bind(@)
			.then ()->
				transforms = @task.options.globalTransform
				promiseBreak(content) if not transforms?.length
				return [content, transforms]
			
			.spread (content, transforms)->
				@applyTransforms(content, transforms, PATH.resolve(@pkgFile.dirPath,'node_modules'))

			.catch promiseBreak.end



	applyTransforms: (content, transforms, useFullPath)->
		Promise.resolve(transforms)
			.map (transform)-> helpers.resolveTransformer(transform, useFullPath)
			.reduce((content, transformer)=>
				filePath = if useFullPath then @filePath else PATH.basename(@filePath)
				transformOpts = extend {_flags:@task.options}, transformer.opts
			
				Promise.resolve()
					.then ()=> getStream streamify(content).pipe(transformer.fn(filePath, transformOpts, @))
					.then (content)=>
						if @fileExt isnt @fileExtOriginal
							@filePath = helpers.changeExtension(@filePath, @fileExt)
						else if transformer.name.includes(/coffeeify|tsify/)
							@filePath = helpers.changeExtension(@filePath, @fileExt='js')

						sourceComment = content.match(sourcemapRegex)
						if sourceComment
							@sourceMap = sourceComment
							content = sourcemap.removeComments(content)

						return content
				
			, content)



	tokenize: (content)->
		unless EXTENSIONS.nonJS.includes(@fileExt)
			try
				@Tokens = Parser.tokenize(content, range:true, sourceType:'module')
				@Tokens.forEach (token, index)-> token.index = index
			catch err
				@task.emit 'TokenizeError', @, err

		return content



	genAST: (content)->
		content = "(#{content})" if @fileExt is 'json'
		try
			@AST = Parser.parse(content, range:true, source:@filePathRel, sourceType:'module')
		catch err
			@task.emit 'ASTParseError', @, err

		return content


	adjustASTLocations: ()->
		# lines = 
		# require('astw')(@AST) (node)=>
		# 	if 


	collectImports: (tokens=@Tokens)->
		switch
			when tokens
				@collectedImports = true
				try
					requires = helpers.collectRequires(tokens)
					imports = helpers.collectImports(tokens)
				catch err
					if err.name is 'TokenError'
						@task.emit('TokenError', @, err)
					else
						@task.emit('GeneralError', @, err)

					return

				imports.concat(requires).forEach (statement)=>
					targetSplit = statement.target.split('$')
					# statement.id = md5(statement.target)
					statement.target = targetSplit[0]
					statement.extract = targetSplit[1]
					statement.range = [Tokens[statement.tokenRange[0]].range[0], Tokens[statement.tokenRange[1]].range[1]]
					statement.source = @
					@importStatements.push(statement)



			when @fileExt is 'pug' or @fileExt is 'jade'
				@collectedImports = true
				@content.replace REGEX.pugImport, (entireLine, priorContent='', keyword, childPath, offset)=>
					statement = {range:[], source:@}
					statement.target = target.value.removeAll(REGEX.quotes).trim()
					statement.priorContent = priorContent
					statement.range[0] = offset + priorContent.length
					statement.range[1] = offset + entireLine.length
					@importStatements.push(statement)


			when @fileExt is 'sass' or @fileExt is 'scss'
				@collectedImports = true
				@content.replace REGEX.cssImport, (entireLine, priorContent='', keyword, childPath, offset)=>
					statement = {range:[], source:@}
					statement.target = target.value.removeAll(REGEX.quotes).trim()
					statement.priorContent = priorContent
					statement.range[0] = offset + priorContent.length
					statement.range[1] = offset + entireLine.length
					@importStatements.push(statement)


		return @importStatements


	collectExports: (tokens=@Tokens)->
		if tokens
			@collectedExports = true
			try
				imports = helpers.collectExports(tokens)
			catch err
				if err.name is 'TokenError'
					@task.emit('TokenError', @, err)
				else
					@task.emit('GeneralError', @, err)

				return

			statements.forEach (statement)=>
				# statement.id = md5(statement.target)
				statement.target = targetSplit[0]
				statement.extract = targetSplit[1]
				statement.range = [Tokens[statement.tokenRange[0]].range[0], Tokens[statement.tokenRange[1]].range[1]]
				statement.source = @
				statement.target ?= @
				@exportStatements.push(statement)


		return @exportStatements


	replaceInlineImports: ()->
		content = @content
		lines = new LinesAndColumns(content)
		
		Promise.bind(@)
			.then ()-> @importStatements.filter (statement)-> statement.type is 'inline'
			.map (statement)->
				range = @offsetRange(statement.range)
				
				replacement = do ()=>
					return '' if statement.removed
					targetContent = if statement.extract then statement.target.extract(statement.extract) else statement.target.content
					return helpers.prepareMultilineReplacement(content, targetContent, lines, range)
				
				@replacedRanges.inlines.push [range[0], newEnd=range[0]+replacement.length, newEnd-range[1]]
				content = content.slice(0,range[0]) + replacement + content.slice(range[1])

			.then ()-> content


	replaceImportStatements: (content)->
		for statement in @importStatements when statement.type is 'module'
			range = @offsetRange(statement.range)
			
			replacement = do ()=>
				return '' if statement.removed
				if not statement.members and not statement.alias
					replacement = "_s$m(#{statement.target.ID})"
					if statement.extract
						replacement += "['#{statement.extract}']"
				else
					alias = statement.alias or helpers.randomVar()
					replacement = "var #{alias} = _s$m(#{statement.target.ID})"

					if statement.members
						nonDefault = Object.exclude(statement.members, 'default')

						if statement.members.default
							replacement += "\nvar #{statement.members.default} = #{alias}['default']"

						for key,keyAlias of nonDefault
							replacement += "\nvar #{keyAlias} = #{alias}['#{key}']"

				replacement = "`#{replacement}`" if @fileExt is 'coffee' or @fileExt is 'iced'
				return helpers.prepareMultilineReplacement(content, replacement, lines, range)
			
			@replacedRanges.imports.push [range[0], newEnd=range[0]+replacement.length, newEnd-range[1]]
			content = content.slice(0,range[0]) + replacement + content.slice(range[1])

		return content


	replaceExportStatements: (content)->
		for statement in @exportStatements
			range = @offsetRange(statement.range)
			
			replacement = do ()=>
				replacement = ''
				if statement.target isnt statement.source
					alias = helpers.randomVar()
					replacement = "var #{alias} = _s$m(#{statement.target.ID})"

					if statement.members
						for keyAlias,key of statement.members
							replacement += "\nexports['#{keyAlias}'] = #{alias}['#{key}']"
					else
						key = helpers.randomVar()
						replacement += "\nvar #{key};for (#{key} in #{alias}) exports[#{key}] = #{alias}[#{key}]"

				else
					if statement.members
						for keyAlias,key of statement.members
							replacement += "\nexports['#{keyAlias}'] = #{key}"
					else
						replacement += '\n'
						if statement.keyword and isDec=statement.keyword.includes(/var|let|const/)
							replacement += "#{statement.keyword} #{statement.identifier} = "
						
						if statement.default
							replacement += "exports['default'] = "
						else if statement.identifier
							replacement += "exports['#{statement.identifier}'] = "

						if statement.keyword and not isDec # function or class
							replacement += "#{statement.keyword} "
							if statement.identifier
								replacement += statement.identifier
				

				replacement = "`#{replacement}`" if @fileExt is 'coffee' or @fileExt is 'iced'
				return helpers.prepareMultilineReplacement(content, replacement, lines, range)
			
			@replacedRanges.exports.push [range[0], newEnd=range[0]+replacement.length, newEnd-range[1]]
			content = content.slice(0,range[0]) + replacement + content.slice(range[1])

		return content


	extract: (key)->
		try
			@parsed ?= JSON.parse(@content)
		catch err
			@task.emit 'ParseError', @, err

		if not @parsed[key] and not Object.has(@parsed, key)
			@task.emit 'ExtractError', @, new Error "requested key '#{key}' not found"
		else
			result = @parsed[key] or Object.get(@parsed, key)
			return if typeof result is 'object' then JSON.stringify(result) else String(result)


	offsetRange: (range)->
		offset = 
		helpers.accumulateRangeOffset(range[0], @replacedRanges.inlines) +
		helpers.accumulateRangeOffset(range[0], @replacedRanges.imports) +
		helpers.accumulateRangeOffset(range[0], @replacedRanges.exports)

		return if not offset then range else [range[0]+offset, range[1]+offset]










module.exports = File