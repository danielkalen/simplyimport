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
GLOBALS = require './constants/globals'
RANGE_ARRAYS = ['inlines', 'imports', 'exports']


class File
	Object.defineProperty @::, 'contentSafe', get: -> @replaceES6Imports(false)
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
		
		if  @pkgTransform = @pkgFile.browserify?.transform
			@pkgTransform = [@pkgTransform] if not helpers.isValidTransformerArray(@pkgTransform)

		return @task.cache[@pathAbs] = @


	checkSyntaxErrors: (content)->
		if @pathExt is 'js'
			content = content.replace REGEX.es6import, ()-> "importPlaceholder()"
			
			if err = Parser.check(content, @pathAbs)
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


	collectRequiredGlobals: ()-> if not @isThirdPartyBundle and not EXTENSIONS.static.includes(@pathExt)
		@task.emit('requiredGlobal',@,'global') if REGEX.vars.global.test(@content) and not REGEX.globalCheck.test(@content)
		@task.emit('requiredGlobal',@,'Buffer') if REGEX.vars.buffer.test(@content) and not REGEX.bufferDec.test(@content)
		@task.emit('requiredGlobal',@,'process') if REGEX.vars.process.test(@content) and not REGEX.processDec.test(@content)
		@task.emit('requiredGlobal',@,'__dirname') if REGEX.vars.__dirname.test(@content)
		@task.emit('requiredGlobal',@,'__filename') if REGEX.vars.__filename.test(@content)
		return


	collectConditionals: ()->
		Promise.bind(@)
			.then ()->
				starts = []
				ends = []

				@content.replace REGEX.ifStartStatement, (e, logic, offset)=>
					starts.push [offset, offset+(e.length-logic.length), logic.trim()]
				
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
							file = @
							jsString = ''
							tokens = Parser.tokenize(start[2])

							helpers.walkTokens tokens, @linesOriginal, null, (token)->
								switch token.type.label
									when 'name'
										if @_prev?.value is '.' or GLOBALS.includes(token.value)
											jsString += token.value
										else
											value = process.env[token.value]
											jsString += " process.env['#{token.value}']"

									when 'string'
										jsString += "'#{token.value}'"

									when 'regexp'
										jsString += "#{token.value.value}"

									when '=','==/!=','||','|','&&','&'
										jsString += ' ' + switch token.value
											when '=','==','===' then '=='
											when '!=','!==' then '!='
											when '||','|' then '||'
											when '&&','&' then '&&'
											else token.value
									else
										if token.type.keyword
											jsString += " #{token.value} "
										else
											jsString += token.value

									# else file.task.emit 'ConditionalError', file, token.start+start[1], token.end+start[1]
							try
								return require('vm').runInNewContext(jsString, {process})
							catch err
								file.task.emit 'ConditionalError', file, err
								return false

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
						@addRangeOffset 'conditionals', [index, index, line.length*-1]

				return outputLines.join('\n')

			.then @saveContent.bind(@, 'contentPostConditionals')
			.catch promiseBreak.end


	saveContent: (milestone, content)->
		if arguments.length is 1
			content = arguments[0]
		else
			@[milestone] = content

		@content = content


	determineType: ()->
		@type = switch
			when @pathExtOriginal is 'ts' then 'module'
			when not REGEX.es6export.test(@content) and not REGEX.commonExport.test(@content) then 'inline'
			else 'module'

		@isDataType = true if EXTENSIONS.data.includes(@pathExt)


	postTransforms: ()->
		if @requiredGlobals.process
			@contentPostTransforms = @content = "var process = require('process');\n#{@content}"
		
		if @requiredGlobals.Buffer
			@contentPostTransforms = @content = "var Buffer = require('buffer').Buffer;\n#{@content}"

		@hashPostTransforms = md5(@contentPostTransforms)
		@linesPostTransforms = new LinesAndColumns(@contentPostTransforms)


	applyAllTransforms: (content=@content)->
		@allTransforms = [].concat @options.transform, @task.options.transform, @task.options.globalTransform#, @pkgTransform
		Promise.resolve(content).bind(@)
			.then @applySpecificTransforms							# ones found in "simplyimport:specific" package.json field
			.then @applyPkgTransforms								# ones found in "browserify.transform" package.json field
			.then(@applyRegularTransforms unless @isExternal)		# ones provided through options.transform (applied to all files of entry-level package)
			.then @applyGlobalTransforms							# ones provided through options.globalTransform (applied to all processed files)


	applySpecificTransforms: (content)->
		Promise.resolve(content).bind(@)
			.then (content)->
				transforms = @options.transform
				forceTransform = switch
					when @pathExt is 'ts'		and not @allTransforms.includes('tsify-transform') 	then 'tsify-transform'
					when @pathExt is 'coffee'	and not @allTransforms.includes('coffeeify')		then 'coffeeify'
					when @pathExt is 'cson'		and not @allTransforms.includes('csonify') 			then 'csonify'
					when @pathExt is 'yml'		and not @allTransforms.includes('yamlify') 			then 'yamlify'
				
				transforms.unshift(forceTransform) if forceTransform
				promiseBreak(content) if not transforms.length
				return [content, transforms]
			
			.spread (content, transforms)->
				@applyTransforms(content, transforms)

			.catch promiseBreak.end


	applyPkgTransforms: (content)->
		Promise.resolve(@pkgTransform).bind(@)
			.tap (transform)-> promiseBreak(content) if not transform
			.filter (transform)->
				name = if typeof transform is 'string' then transform else transform[0]
				return not name.toLowerCase().includes 'simplyimport/compat'
			
			.then (transforms)-> [content, transforms]
			.spread (content, transforms)->
				@applyTransforms(content, transforms)

			.catch promiseBreak.end


	applyRegularTransforms: (content)->
		Promise.bind(@)
			.then ()->
				transforms = @task.options.transform
				promiseBreak(content) if not transforms?.length or @options.skipTransform
				return [content, transforms]
			
			.spread (content, transforms)->
				@applyTransforms(content, transforms)

			.catch promiseBreak.end


	applyGlobalTransforms: (content)->
		Promise.bind(@)
			.then ()->
				transforms = @task.options.globalTransform
				promiseBreak(content) if not transforms?.length or @options.skipTransform
				return [content, transforms]
			
			.spread (content, transforms)->
				@applyTransforms(content, transforms)

			.catch promiseBreak.end



	applyTransforms: (content, transforms)->
		lastTransformer = null
		
		Promise.resolve(transforms).bind(@)
			.filter (transform)-> not @task.options.ignoreTransform.includes(transform)
			.map (transform)->
				lastTransformer = name:transform, fn:transform
				helpers.resolveTransformer(transform, Path.resolve(@pkgFile.dirPath,'node_modules'))
			
			.reduce((content, transformer)->
				lastTransformer = transformer
				transformOpts = extend {_flags:@task.options}, transformer.opts
				prevContent = content

				Promise.bind(@)
					.then ()-> transformer.fn(@pathAbs, transformOpts, @, content)
					.tap (result)->
						switch
							when helpers.isStream(result) then result
							when typeof result is 'string' then promiseBreak(result)
							when typeof result is 'function' then promiseBreak(result(content))
							else throw new Error "invalid result of type '#{typeof result}' received from transformer"

					.then (transformStream)-> getStream streamify(content).pipe(transformStream)
					.catch promiseBreak.end
					.then (content)->
						return content if content is prevContent
						if transformer.name.includes(/coffeeify|typescript-compiler/)
							@pathExt = 'js'
						else if transformer.name.includes(/csonify|yamlify/)
							@pathExt = 'json'
							content = content.replace /^module\.exports\s*=\s*/, ''
							content = content.slice(0,-1) if content[content.length-1] is ';'
						
						if @pathExt isnt @pathExtOriginal
							@pathAbs = helpers.changeExtension(@pathAbs, @pathExt)

						@sourceMap ?= sourcemapConvert.fromSource(content)?.sourcemap
						return content
				
			, content)
			.catch (err)->
				@task.emit 'TransformError', @, err, lastTransformer



	tokenize: ()->
		unless EXTENSIONS.nonJS.includes(@pathExt)
			try
				@Tokens = Parser.tokenize(@content, range:true, sourceType:'module')
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


	replaceES6Imports: (save=true)->
		hasImports = false
		newContent = @content.replace REGEX.es6import, (original, meta, defaultMember='', members='', childPath)->
			hasImports = true
			body = "#{childPath}"
			body += ",'#{meta.replace /\s+from\s+/, ''}'" if meta
			replacement = "_$sm(#{body})"
			lenDiff = original.length - replacement.length
			if lenDiff > 0
				padding = ' '.repeat(lenDiff)
				replacement = "_$sm(#{body}#{padding})"
			return replacement

		if hasImports and @pathExt is 'ts'
			newContent = "declare function _$sm(...a: any[]): any;\n#{newContent}"

		@content = newContent if save
		return newContent


	restoreES6Imports: ()->
		@content = @content.replace REGEX.tempImport, (entire, childPath, meta='')->
			childPath = childPath.slice(1,-1)
			meta = meta.slice(1,-1)
			body = if meta then "#{meta} from " else ""
			body += "'#{childPath}'"
			replacement = "import #{body}"
			return replacement


	collectForceInlineImports: ()->
		@content.replace REGEX.inlineImport, (entire, childPath, offset)=>
			statement = helpers.newImportStatement()
			statement.source = @
			statement.target = childPath.removeAll(REGEX.quotes).trim()
			statement.range[0] = offset
			statement.range[1] = offset + entire.length
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
					statements = imports.concat(requires).sortBy('tokenRange[0]')
				catch err
					if err.name is 'TokenError'
						@task.emit('TokenError', @, err)
					else
						@task.emit('GeneralError', @, err)

					return

				statements.forEach (statement, index)=>
					targetSplit = statement.target.split(REGEX.extractDelim)
					statement.target = targetSplit[0]
					statement.extract = targetSplit[1]
					statement.range[0] = tokens[statement.tokenRange[0]].start
					statement.range[1] = tokens[statement.tokenRange[1]].end
					prevRange = statement.range
					statement.range = @deoffsetRange(statement.range, ['inlines'], true)
					# console.log (-> {index, @target, @range}).call(statement)
					# console.log(@contentPostTokenize) if statement.target is 'c'
					# console.log(tokens.map (i)-> [i.start, i.end]) if statement.target is 'c'
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
				statement.range = [tokens[statement.tokenRange[0]].start, tokens[statement.tokenRange[1]].end]
				statement.source = @
				statement.target ?= @
				if statement.decs
					for dec,range of statement.decs
						throw new Error "#{dec} = #{JSON.stringify range}" if Object.keys(range).length is 1
						statement.decs[dec] = @content.slice(range.start, range.end)

				@exportStatements.push(statement)
				@hasDefaultExport = true if statement.default


		return @exportStatements


	replaceForceInlineImports: ()->
		@replaceInlineImports('inline-forced')


	replaceInlineImports: (type='inline')->
		content = @content
		lines = @linesPostTransforms or @linesOriginal # the latter will be used when type==='inline-forced'

		Promise.bind(@)
			.then ()-> @importStatements.filter {type}
			.map (statement)->
				range = @offsetRange(statement.range, null, 'inlines')
				replacement = do ()=>
					return '' if statement.excluded
					targetContent = if statement.extract then statement.target.extract(statement.extract) else statement.target.content
					targetContent = helpers.prepareMultilineReplacement(content, targetContent, lines, statement.range)
					targetContent = '{}' if not targetContent

					if EXTENSIONS.compat.includes(statement.target.pathExt)
						targetContent = "(#{targetContent})" if content[range[1]] is '.' or content[range[1]] is '('

					return targetContent
				
				# if @path.endsWith('moment/src/lib/units/timezone.js')
				# console.log statement.range, range, [range[0], newEnd=range[0]+replacement.length, newEnd-range[1]]
				# console.log require('chalk').yellow content.slice(range[0], range[1])
				# console.log require('chalk').green replacement
				# console.log require('chalk').dim content
				# console.log '\n\n'
				@addRangeOffset 'inlines', [range[0], newEnd=range[0]+replacement.length, newEnd-range[1]]
				content = content.slice(0,range[0]) + replacement + content.slice(range[1])

			.then ()-> content


	replaceImportStatements: (content)->
		loader = @task.options.loaderName
		for statement,index in @importStatements when statement.type is 'module'

			range = @offsetRange(statement.range, null, 'imports')
			replacement = do ()=>
				return "require('#{statement.target}')" if statement.excluded
				if not statement.members and not statement.alias # commonJS import / side-effects es6 import
					replacement = "#{loader}(#{statement.target.IDstr})"
					if statement.extract
						replacement += "['#{statement.extract}']"
					
					else if statement.target.hasDefaultExport
						replacement = "#{replacement} ? #{replacement}.default : #{replacement}"
						replacement = "(#{replacement})" if content[range[1]] is '.' or content[range[1]] is '('

				else
					alias = statement.alias or helpers.randomVar()
					replacement = "var #{alias} = #{loader}(#{statement.target.IDstr})"

					if statement.members
						nonDefault = Object.exclude(statement.members, (k,v)-> v is 'default')
						decs = []
						decs.push("#{statement.members.default} = #{alias}.default") if statement.members.default
						decs.push("#{keyAlias} = #{alias}.#{key}") for key,keyAlias of nonDefault
						replacement += ", #{decs.join ', '};"

				return helpers.prepareMultilineReplacement(content, replacement, @linesPostTransforms, statement.range)

			@replacedRanges.imports.push [range[0], newEnd=range[0]+replacement.length, newEnd-range[1]]
			content = content.slice(0,range[0]) + replacement + content.slice(range[1])

		return content


	replaceExportStatements: (content)->
		loader = @task.options.loaderName
		for statement,index in @exportStatements
			
			range = @offsetRange(statement.range, null, 'exports')
			replacement = do ()=>
				replacement = ''
			
				if statement.target isnt statement.source
					alias = helpers.randomVar()
					replacement = "var #{alias} = #{loader}(#{statement.target.IDstr})\n"

					if statement.members
						decs = []
						decs.push("exports.#{keyAlias} = #{alias}.#{key}") for keyAlias,key of statement.members
						replacement += decs.join ', '
					
					else
						key = helpers.randomVar()
						replacement += "var #{key}; for (#{key} in #{alias}) exports[#{key}] = #{alias}[#{key}];"


				else
					if statement.members
						decs = []
						decs.push("exports.#{keyAlias} = #{key}") for keyAlias,key of statement.members
						replacement += decs.join ', '
					

					else if statement.decs
						decs = Object.keys(statement.decs)
						values = Object.values(statement.decs)

						replacement += "#{statement.keyword} #{values.join ', '}\n"
						replacement += "exports.#{dec} = #{dec}; " for dec in decs


					else
						if statement.default
							replacement += "exports.default = "
							replacement += statement.identifier if statement.identifier and not statement.keyword # assignment-expr-left
						
						else if statement.identifier
							replacement += "exports.#{statement.identifier} = "

						if statement.keyword# and not isDec # function or class
							replacement += "#{statement.keyword} "
							if statement.identifier
								replacement = "var #{statement.identifier} = #{replacement}"
				

				return helpers.prepareMultilineReplacement(content, replacement, @linesPostTransforms, statement.range)

			@addRangeOffset 'exports', [range[0], newEnd=range[0]+replacement.length, newEnd-range[1]]
			content = content.slice(0,range[0]) + replacement + content.slice(range[1])

		content += "\nexports.__esModule=true" if @exportStatements.length
		return content


	extract: (key, returnActual)->
		try
			@parsed ?= JSON.parse(@content)
		catch err
			@task.emit 'DataParseError', @, err

		if not @parsed[key] and not Object.has(@parsed, key)
			@task.emit 'ExtractError', @, new Error "requested key '#{key}' not found"
		else
			result = @parsed[key] or Object.get(@parsed, key)
			return result if returnActual
			return JSON.stringify(result)


	offsetRange: (range, targetArrays, sourceArray)->
		offset = 0
		targetArrays ?= RANGE_ARRAYS
		for array,index in targetArrays
			rangeOffset = if index > targetArrays.indexOf(sourceArray) then offset else 0
			considerDiff = sourceArray isnt 'imports' or array is sourceArray
			breakOnInnerRange = array isnt 'exports'
			offset = helpers.accumulateRangeOffsetBelow(range, @replacedRanges[array], offset, {rangeOffset, considerDiff, breakOnInnerRange})

		return if not offset then range else [range[0]+offset, range[1]+offset]


	deoffsetRange: (range, targetArrays)->
		offset = 0
		targetArrays ?= RANGE_ARRAYS
		for array in targetArrays
			offset = helpers.accumulateRangeOffsetBelow(range, @replacedRanges[array], offset, isDeoffset:true)

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