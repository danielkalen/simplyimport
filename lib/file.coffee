Promise = require 'bluebird'
promiseBreak = require 'promise-break'
streamify = require 'streamify-string'
getStream = require 'get-stream'
Path = require 'path'
md5 = require 'md5'
extend = require 'extend'
Parser = require './external/parser'
LinesAndColumns = require('lines-and-columns').default
sourcemapConvert = require 'convert-source-map'
helpers = require './helpers'
REGEX = require './constants/regex'
EXTENSIONS = require './constants/extensions'
RANGE_ARRAYS = ['conditionals', 'inlines', 'imports', 'exports']


class File
	constructor: (@task, state)->
		extend(@, state)
		@IDstr = JSON.stringify(@ID)
		@tokens = @AST = @parsed = null
		@exportStatements = []
		@importStatements = []
		@replacedRanges = imports:[], exports:[], inlines:[], conditionals:[]
		@conditionals = []
		@requiredGlobals = Object.create(null)
		@isThirdPartyBundle = false
		@pathExtOriginal = @pathExt
		@contentOriginal = @content
		@linesOriginal = new LinesAndColumns(@content)
		@options.transform ?= []
		
		if @isEntry or @isExternalEntry
			
			if  @pkgTransform = @pkgFile.browserify?.transform
				@pkgTransform = [@pkgTransform] if helpers.isValidTransformerArray(@pkgTransform)


		return @task.cache[@pathAbs] = @


	checkSyntaxErrors: (content)->
		if @pathExt is 'js'
			content = content.replace REGEX.es6import, (entire,meta,path)->
				"importPlaceholder()"
			
			if err = require('syntax-error')(content, @pathAbs)
				@task.emit 'SyntaxError', @, err


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

		@isThirdPartyBundle = @isThirdPartyBundle or
			(
				REGEX.requireArg.test(@content) and
				REGEX.commonImportReal.test(@content)
			)


	collectRequiredGlobals: ()-> if not @isThirdPartyBundle
		@task.emit('requiredGlobal',@,'global') if REGEX.vars.global.test(@content) and not REGEX.globalCheck.test(@content)
		@task.emit('requiredGlobal',@,'process') if REGEX.vars.process.test(@content) and not REGEX.processRequire.test(@content) and not REGEX.processDec.test(@content)
		@task.emit('requiredGlobal',@,'__dirname') if REGEX.vars.__dirname.test(@content)
		@task.emit('requiredGlobal',@,'__filename') if REGEX.vars.__filename.test(@content)
		return


	collectConditionals: ()->
		Promise.bind(@)
			.then ()->
				starts = []
				ends = []

				@content.replace REGEX.ifStartStatement, (e, logic, offset)=>
					starts.push [offset, logic.trim()]
				
				@content.replace REGEX.ifEndStatement, (e, offset)=>
					ends.push [offset]

				starts.forEach (start)=>
					end = ends.find (end)-> end[0] > start[0]
					end ?= [@content.length - 1]
					@conditionals.push 
						range: [start[0], end[0]]
						start: @linesOriginal.locationForIndex(start[0]).line
						end: @linesOriginal.locationForIndex(end[0]).line
						match: do ()=>
							# matchTotal = true
							rules = []
							file = @
							jsString = ''
							tokens = Parser.tokenize(start[1])
							
							helpers.walkTokens tokens, @linesOriginal, null, (token)->
								switch token.type
									when 'Identifier'
										value = process.env[token.value]
										jsString += " process.env['#{token.value}']"

									when 'String','Literal'
										jsString += " #{token.value}"

									when 'Punctuator'
										jsString += ' ' + switch token.value
											when '=' then '=='
											when '!=' then '!='
											when '||','|' then '||'
											when '&&','&' then '&&'

									else file.task.emit 'ConditionalError', file, token, [start[0], end[0]]

							return require('vm').runInNewContext(jsString)

			.tap ()-> promiseBreak() if not @conditionals.length
			.then ()->
				linesToRemove = []
				@conditionals.forEach (conditional)=>
					if conditional.match
						linesToRemove.push conditional.start
						linesToRemove.push conditional.end
					else
						linesToRemove.push [conditional.start..conditional.end]...
					return
				
				return new ()-> @[index]=true for index in linesToRemove; @

			.then (linesToRemove)->
				outputLines = []
				@content.lines (line, index)=>
					if not linesToRemove[index]
						outputLines.push(line)
					else
						index = @linesOriginal.indexForLocation line:index, column:0
						@replacedRanges.push [index, index, line.length]

				return outputLines.join('\n')

			.then @saveContentMilestone.bind(@, 'contentPostConditionals')
			.catch promiseBreak.end


	saveContent: (content)->
		throw new Error("content is undefined") if content is undefined
		@content = content


	saveContentMilestone: (milestone, content)->
		@[milestone] = @saveContent(content)


	determineType: ()->
		@type = switch
			when @isEntry then 'module'
			when not REGEX.es6export.test(@content) and not REGEX.commonExport.test(@content) then 'inline'
			else 'module'

		@isDataType = true if EXTENSIONS.data.includes(@pathExt)


	postTransforms: ()->
		@hashPostTransforms = md5(@contentPostTransforms)
		@linesPostTransforms = new LinesAndColumns(@contentPostTransforms)


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
					when @pathExt is 'ts'		and not @allTransforms.includes('tsify') 		then 'tsify'
					when @pathExt is 'coffee'	and not @allTransforms.includes('coffeeify')	then 'coffeeify'
					when @pathExt is 'cson'		and not @allTransforms.includes('csonify') 		then 'csonify'
					when @pathExt is 'yml'		and not @allTransforms.includes('yamlify') 		then 'yamlify'
				
				transforms.unshift(forceTransform) if forceTransform
				promiseBreak(content) if not transforms.length
				return [content, transforms]
			
			.spread (content, transforms)->
				@applyTransforms(content, transforms, Path.resolve(@pkgFile.dirPath,'node_modules'))

			.catch promiseBreak.end


	applyPkgTransforms: (content)->
		Promise.resolve(@pkgTransform).bind(@)
			.tap (transform)-> promiseBreak(content) if not transform
			.filter (transform)->
				name = if typeof transform is 'string' then transform else transform[0]
				return not name.toLowerCase().includes 'simplyimport/compat'
			
			.then (transforms)-> [content, transforms]
			.spread (content, transforms)->
				@applyTransforms(content, transforms, Path.resolve(@pkgFile.dirPath,'node_modules'))

			.catch promiseBreak.end


	applyGlobalTransforms: (content)->
		Promise.bind(@)
			.then ()->
				transforms = @task.options.globalTransform
				promiseBreak(content) if not transforms?.length
				return [content, transforms]
			
			.spread (content, transforms)->
				@applyTransforms(content, transforms, Path.resolve(@pkgFile.dirPath,'node_modules'))

			.catch promiseBreak.end



	applyTransforms: (content, transforms, useFullPath)->
		Promise.resolve(transforms)
			.map (transform)-> helpers.resolveTransformer(transform, useFullPath)
			.reduce((content, transformer)=>
				pathAbs = if useFullPath then @pathAbs else Path.basename(@pathAbs)
				transformOpts = extend {_flags:@task.options}, transformer.opts
			
				Promise.resolve()
					.then ()=> getStream streamify(content).pipe(transformer.fn(pathAbs, transformOpts, @))
					.then (content)=>
						if @pathExt isnt @pathExtOriginal
							@pathAbs = helpers.changeExtension(@pathAbs, @pathExt)
						else if transformer.name.includes(/coffeeify|tsify/)
							@pathAbs = helpers.changeExtension(@pathAbs, @pathExt='js')

						@sourceMap ?= sourcemapConvert.fromSource(content)?.sourcemap
						return content
				
			, content)



	tokenize: ()->
		unless EXTENSIONS.nonJS.includes(@pathExt)
			try
				@Tokens = Array.from Parser.tokenize(@content, range:true, sourceType:'module')
			catch err
				@task.emit 'TokenizeError', @, err
			
			@Tokens.forEach (token, index)-> token.index = index

		return @content



	genAST: ()->
		content = if @pathExt is 'json' then "(#{@content})" else @content
		@checkSyntaxErrors(content)
		try
			@AST = Parser.parse(content, range:true, loc:true, comment:true, source:@pathRel, sourceType:'module')
		catch err
			@task.emit 'ASTParseError', @, err

		return content


	genSourceMap: ()->
		if @sourceMap
			return @sourceMap
		
		else if @AST
			@sourceMap = JSON.parse Parser.generate(@AST, comment:true, sourceMap:true)


	adjustSourceMap: ()-> if @sourceMap
		return @sourceMap is @contentOriginal is @content
		output = require('inline-source-map')(file:@pathRel)
		mappings = require('combine-source-map/lib/mappings-from-map')(@sourceMap)
		currentOffset = 0
		
		# for mapping in mappings
		# 	mapping


	collectForceInlineImports: ()->
		@content.replace REGEX.inlineImport, (entireLine, priorContent='', keyword, childPath, trailingContent='', offset)=>
			statement = helpers.newImportStatement()
			statement.source = @
			statement.target = childPath.removeAll(REGEX.quotes).trim()
			statement.range[0] = offset + priorContent.length
			statement.range[1] = offset + (entireLine.length - trailingContent.length)
			statement.type = 'inline-forced'
			@importStatements.push(statement)
		
		return @importStatements


	collectImports: (tokens=@Tokens)->
		switch
			when tokens
				@collectedImports = true
				
				try
					requires = helpers.collectRequires(tokens, @linesPostTransforms)
					imports = helpers.collectImports(tokens, @linesPostTransforms)
					statements = imports.concat(requires)
				catch err
					if err.name is 'TokenError'
						@task.emit('TokenError', @, err)
					else
						@task.emit('GeneralError', @, err)

					return

				statements.forEach (statement)=>
					targetSplit = statement.target.split('$')
					statement.target = targetSplit[0]
					statement.extract = targetSplit[1]
					statement.range[0] = tokens[statement.tokenRange[0]].start
					statement.range[1] = tokens[statement.tokenRange[1]].end
					statement.range = @deoffsetRange(statement.range, ['inlines'], true)
					statement.source = @
					@importStatements.push(statement)



			when @pathExt is 'pug' or @pathExt is 'jade'
				@collectedImports = true
				@content.replace REGEX.pugImport, (entireLine, priorContent='', keyword, childPath, offset)=>
					statement = helpers.newImportStatement()
					statement.source = @
					statement.target = childPath.removeAll(REGEX.quotes).trim()
					statement.range[0] = offset + priorContent.length
					statement.range[1] = offset + entireLine.length
					statement.type = 'inline-forced'
					@importStatements.push(statement)


			when @pathExt is 'sass' or @pathExt is 'scss'
				@collectedImports = true
				@content.replace REGEX.cssImport, (entireLine, priorContent='', keyword, childPath, offset)=>
					statement = helpers.newImportStatement()
					statement.source = @
					statement.target = childPath.removeAll(REGEX.quotes).trim()
					statement.range[0] = offset + priorContent.length
					statement.range[1] = offset + entireLine.length
					statement.type = 'inline-forced'
					@importStatements.push(statement)


		return @importStatements.sortBy('range[0]')


	collectExports: (tokens=@Tokens)->
		if tokens
			@collectedExports = true
			try
				statements = helpers.collectExports(tokens, @linesPostTransforms)
			catch err
				if err.name is 'TokenError'
					@task.emit('TokenError', @, err)
				else
					@task.emit('GeneralError', @, err)

				return

			statements.forEach (statement)=>
				statement.target = targetSplit[0]
				statement.extract = targetSplit[1]
				statement.range = [Tokens[statement.tokenRange[0]].start, Tokens[statement.tokenRange[1]].end]
				statement.source = @
				statement.target ?= @
				@exportStatements.push(statement)


		return @exportStatements


	replaceForceInlineImports: ()->
		@replaceInlineImports('inline-forced')


	replaceInlineImports: (targetType='inline')->
		content = @content
		lines = @linesPostTransforms or @linesOriginal # the latter will be used when targetType==='inline-forced'

		Promise.bind(@)
			.then ()-> @importStatements.filter (statement)-> statement.type is targetType
			.map (statement)->
				range = @offsetRange(statement.range)
				replacement = do ()=>
					targetContent = if statement.extract then statement.target.extract(statement.extract) else statement.target.content
					targetContent = helpers.prepareMultilineReplacement(content, targetContent, lines, statement.range)

					if EXTENSIONS.compat.includes(statement.target.pathExt)
						targetContent = "(#{targetContent})" if content[range[1]] is '.' or content[range[1]] is '('

					return targetContent
				
				@addRangeOffset 'inlines', [range[0], newEnd=range[0]+replacement.length, newEnd-range[1]]
				content = content.slice(0,range[0]) + replacement + content.slice(range[1])

			.then ()-> content


	replaceImportStatements: (content)->
		for statement in @importStatements when statement.type is 'module'

			replacement = do ()=>
				if not statement.members and not statement.alias
					replacement = "require(#{statement.target.IDstr})"
					if statement.extract
						replacement += "['#{statement.extract}']"
				else
					alias = statement.alias or helpers.randomVar()
					replacement = "var #{alias} = require(#{statement.target.IDstr})"

					if statement.members
						nonDefault = Object.exclude(statement.members, 'default')

						if statement.members.default
							replacement += "\nvar #{statement.members.default} = #{alias}['default']"

						for key,keyAlias of nonDefault
							replacement += "\nvar #{keyAlias} = #{alias}['#{key}']"

				replacement = "`#{replacement}`" if @pathExt is 'coffee' or @pathExt is 'iced'
				return helpers.prepareMultilineReplacement(content, replacement, @linesPostTransforms, statement.range)
			
			range = @offsetRange(statement.range)
			@replacedRanges.imports.push [range[0], newEnd=range[0]+replacement.length, newEnd-range[1]]
			content = content.slice(0,range[0]) + replacement + content.slice(range[1])

		return content


	replaceExportStatements: (content)->
		for statement in @exportStatements
			
			replacement = do ()=>
				replacement = ''
				if statement.target isnt statement.source
					alias = helpers.randomVar()
					replacement = "var #{alias} = require(#{statement.target.IDstr})"

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
				

				replacement = "`#{replacement}`" if @pathExt is 'coffee' or @pathExt is 'iced'
				return helpers.prepareMultilineReplacement(content, replacement, @linesPostTransforms, statement.range)
			
			range = @offsetRange(statement.range)
			@replacedRanges.exports.push [range[0], newEnd=range[0]+replacement.length, newEnd-range[1]]
			content = content.slice(0,range[0]) + replacement + content.slice(range[1])

		content += "\nexports.__esModule=true;" if @exportStatements.length
		return content


	extract: (key)->
		try
			@parsed ?= JSON.parse(@content)
		catch err
			@task.emit 'DataParseError', @, err

		if not @parsed[key] and not Object.has(@parsed, key)
			@task.emit 'ExtractError', @, new Error "requested key '#{key}' not found"
		else
			result = @parsed[key] or Object.get(@parsed, key)
			return if typeof result is 'object' then JSON.stringify(result) else String(result)


	offsetRange: (range, targetArrays)->
		offset = 0
		targetArrays ?= RANGE_ARRAYS
		for array in targetArrays
			offset += helpers.accumulateRangeOffsetBelow(range, @replacedRanges[array])

		return if not offset then range else [range[0]+offset, range[1]+offset]

	deoffsetRange: (range, targetArrays)->
		offset = 0
		targetArrays ?= RANGE_ARRAYS
		for array in targetArrays
			offset += helpers.accumulateRangeOffsetBelow(range, @replacedRanges[array])

		return if not offset then range else [range[0]-offset, range[1]-offset]


	addRangeOffset: (target, range)->
		ranges = @replacedRanges[target]
		ranges.push(range)
		ranges.sortBy('0')
		insertedIndex = i = ranges.indexOf(range)
		
		if insertedIndex < ranges.length - 1
			while largerRange = ranges[++i]
				largerRange[0] += range[2]
				largerRange[1] += range[2]
		return


	destroy: ()->
		ranges.length = 0 for k,ranges of @replacedRanges
		@exportStatements.length = 0
		@importStatements.length = 0
		@conditionals.length = 0
		@tokens?.length = 0
		delete @ID
		delete @AST
		delete @tokens
		delete @exportStatements
		delete @importStatements
		delete @conditionals
		delete @requiredGlobals
		delete @replacedRanges
		delete @parsed
		delete @options
		delete @linesPostTransforms
		delete @linesOriginal
		delete @pkgTransform
		delete @task
		for prop of @ when prop.startsWith('content') or prop.startsWith('file')
			delete @[prop] if @hasOwnProperty(prop)


		return









module.exports = File