Promise = require 'bluebird'
promiseBreak = require 'promise-break'
streamify = require 'streamify-string'
getStream = require 'get-stream'
Path = require './helpers/path'
stringHash = require 'string-hash'
chalk = require 'chalk'
extend = require 'extend'
stringPos = require 'string-pos'
Parser = require './external/parser'
SourceMap = require './sourceMap'
helpers = require './helpers'
REGEX = require './constants/regex'
EXTENSIONS = require './constants/extensions'
GLOBALS = require './constants/globals'
RANGE_ARRAYS = ['imports', 'exports']
debug = require('debug')('simplyimport:file')


class File
	Object.defineProperty @::, 'contentSafe', get: -> @replaceES6Imports(false)
	constructor: (@task, state)->
		extend(@, state)
		@options.transform ?= []
		@IDstr = JSON.stringify(@ID)
		@tokens = @AST = @parsed = null
		@time = 0
		@statements = []
		@inlineStatements = []
		@conditionals = []
		@requiredGlobals = Object.create(null)
		@isThirdPartyBundle = false
		@pathExtOriginal = @pathExt
		@contentOriginal = @content
		@linesOriginal = helpers.lines(@content)
		@sourceMap = new SourceMap(@)
		@options.placeholder = helpers.resolvePlaceholders(@)
		@pkgEntry = helpers.resolvePackageEntry(@pkg)
		@pkgTransform = @pkg.browserify?.transform
		@pkgTransform = helpers.normalizeTransforms(@pkgTransform) if @pkgTransform
		@pkgTransform = do ()=>
			transforms = @pkg.simplyimport?.transform if @isExternal
			transforms ?= @pkg.browserify?.transform
			if transforms
				helpers.normalizeTransforms(transforms)

		if REGEX.shebang.test(@content)
			@content = @contentOriginal = @content.replace REGEX.shebang, (@shebang)=> return ''

		return @task.cache[@pathAbs] = @

	timeStart: ()->
		@timeEnd() if @startTime
		@startTime = Date.now()
	
	timeEnd: ()->
		@time += Date.now() - (@startTime or Date.now())
		@startTime = null


	checkSyntaxErrors: ((content)->
		debug "checking for syntax errors #{@pathDebug}"
		if @pathExt is 'js'
			@timeStart()
			content = content.replace REGEX.es6import, ()-> "importPlaceholder()"
			
			if err = Parser.check(content, @pathAbs)
				@task.emit 'SyntaxError', @, err

			@timeEnd()
	).memoize()


	checkIfIsThirdPartyBundle: ()->
		debug "checking 3rd party bundle status #{@pathDebug}"
		@timeStart()
		### istanbul ignore next ###
		@isThirdPartyBundle =
			@content.includes('.code="MODULE_NOT_FOUND"') or
			@content.includes('__webpack_require__') or
			@content.includes('System.register') or 
			@content.includes("' has not been defined'") or
			REGEX.moduleCheck.test(@content) or
			REGEX.defineCheck.test(@content) or
			REGEX.requireCheck.test(@content)

		@hasRequires = REGEX.commonImportReal.test(@content)
		@hasOwnRequireSystem =
			REGEX.requireDec.test(@content) or
			REGEX.requireArg.test(@content) and @hasRequires

		@isThirdPartyBundle = @isThirdPartyBundle or @hasOwnRequireSystem
		@options.skip ?= @isThirdPartyBundle and @hasOwnRequireSystem and @hasRequires
		@timeEnd()


	collectRequiredGlobals: ()-> if not @isThirdPartyBundle and not EXTENSIONS.static.includes(@pathExt)
		@task.emit('requiredGlobal',@,'global') if REGEX.vars.global.test(@content) and not REGEX.globalCheck.test(@content)
		@task.emit('requiredGlobal',@,'Buffer') if REGEX.vars.buffer.test(@content) and not REGEX.bufferDec.test(@content)
		@task.emit('requiredGlobal',@,'process') if REGEX.vars.process.test(@content) and not REGEX.processDec.test(@content)
		@task.emit('requiredGlobal',@,'__dirname') if REGEX.vars.__dirname.test(@content)
		@task.emit('requiredGlobal',@,'__filename') if REGEX.vars.__filename.test(@content)
		return


	collectConditionals: ()->
		Promise.bind(@)
			.tap ()-> debug "collecting conditionals #{@pathDebug}"
			.tap @timeStart
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
						start: stringPos(@contentOriginal, start[0]).line-1
						end: stringPos(@contentOriginal, end[0]).line-1
						match: @task.options.matchAllConditions or do ()=>
							file = @
							jsString = ''
							tokens = Parser.tokenize(start[2])
							env = @task.options.env
							BUNDLE_TARGET = @task.options.target

							helpers.walkTokens tokens, @contentOriginal, null, (token)->
								switch token.type.label
									when 'name'
										if @_prev?.value is '.' or GLOBALS.includes(token.value)
											jsString += token.value
										else if token.value is 'BUNDLE_TARGET'
											jsString += " '#{BUNDLE_TARGET}'"
										else
											value = env[token.value]
											jsString += " env['#{token.value}']"

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
								return require('vm').runInNewContext(jsString, {env})
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
				@content.split('\n').forEach (line, index)=>
					if not linesToRemove[index]
						outputLines.push(line)
					else
						index = stringPos.toIndex(@contentOriginal,{line:index+1, column:0})

				return outputLines.join('\n')

			.then @saveContent.bind(@, 'contentPostConditionals')
			.catch promiseBreak.end
			.tap @timeEnd


	saveContent: (milestone, content)->
		content = @sourceMap.update(content)
		if arguments.length is 1
			content = arguments[0]
		else
			@[milestone] = content

		@content = content


	determineType: ()->
		@type = switch
			when @type is 'inline-forced' then @type
			when @pathExtOriginal is 'ts' then 'module'
			when not REGEX.es6export.test(@content) and not REGEX.commonExport.test(@content) then 'inline'
			else 'module'

		@isDataType = true if EXTENSIONS.data.includes(@pathExt)


	postScans: ()->
		@options.extractDefaults ?= true
		@hasDefaultExport ?=
			@type isnt 'inline' and
			REGEX.defaultExport.test(@content) and
			not REGEX.defaultExportDeassign.test(@content)


	postTransforms: ()->
		debug "running post-transform functions #{@pathDebug}"
		@timeStart()
		@contentPostTransforms = @content = @sourceMap.update(@content)
		
		if @requiredGlobals.process
			@contentPostTransforms = @content = "var process = require('process');\n#{@content}"
			@sourceMap.addNullRange(0, 34, true)
		
		if @requiredGlobals.Buffer
			@contentPostTransforms = @content = "var Buffer = require('buffer').Buffer;\n#{@content}"
			@sourceMap.addNullRange(0, 39, true)

		@hashPostTransforms = stringHash(@contentPostTransforms)
		@timeEnd()


	applyAllTransforms: (content=@content)->
		@allTransforms = [].concat @options.transform, @task.options.transform, @task.options.globalTransform, @pkgTransform

		Promise.resolve(content).bind(@)
			.tap ()-> debug "start applying transforms #{@pathDebug}"
			.then @applySpecificTransforms							# ones found in "simplyimport:specific" package.json field
			.then @applyPkgTransforms								# ones found in "browserify.transform" package.json field
			.then(@applyRegularTransforms unless @isExternal)		# ones provided through options.transform (applied to all files of entry-level package)
			.then @applyGlobalTransforms							# ones provided through options.globalTransform (applied to all processed files)
			.tap ()-> debug "done applying transforms #{@pathDebug}"


	applySpecificTransforms: (content)->
		Promise.resolve(content).bind(@)
			.then (content)->
				transforms = @options.transform
				forceTransform = switch
					when @pathExt is 'cson'		and not @allTransforms.includes('csonify') 			then 'csonify'
					when @pathExt is 'yml'		and not @allTransforms.includes('yamlify') 			then 'yamlify'
					when @pathExt is 'ts'		and not @allTransforms.includes('tsify-transform') 	then 'tsify-transform'
					when @pathExt is 'coffee'	and not @allTransforms.some((t)-> t?.includes('coffeeify')) then 'coffeeify-cached'
				
				transforms.unshift(forceTransform) if forceTransform
				promiseBreak(content) if not transforms.length
				return [content, transforms]
			
			.spread (content, transforms)->
				@applyTransforms(content, transforms, 'specific')

			.catch promiseBreak.end


	applyPkgTransforms: (content)->
		Promise.resolve(@pkgTransform).bind(@)
			.tap (transform)-> promiseBreak(content) if not transform or @options.skip
			.filter (transform)->
				name = if typeof transform is 'string' then transform else transform[0]
				return not name.toLowerCase().includes 'simplyimport/compat'
			
			.then (transforms)-> [content, transforms]
			.spread (content, transforms)->
				@applyTransforms(content, transforms, 'package')

			.catch promiseBreak.end


	applyRegularTransforms: (content)->
		Promise.bind(@)
			.then ()->
				transforms = @task.options.transform
				promiseBreak(content) if not transforms?.length or @options.skipTransform
				return [content, transforms]
			
			.spread (content, transforms)->
				@applyTransforms(content, transforms, 'options')

			.catch promiseBreak.end


	applyGlobalTransforms: (content)->
		Promise.bind(@)
			.then ()->
				transforms = @task.options.globalTransform
				promiseBreak(content) if not transforms?.length or @options.skipTransform
				return [content, transforms]
			
			.spread (content, transforms)->
				@applyTransforms(content, transforms, 'global')

			.catch promiseBreak.end



	applyTransforms: (content, transforms, label)->
		lastTransformer = null
		prevContent = content
		
		Promise.resolve(transforms).bind(@)
			.tap @timeStart
			.filter (transform)-> not @task.options.ignoreTransform.includes(transform)
			.map (transform)->
				lastTransformer = name:transform, fn:transform
				helpers.resolveTransformer(transform, @)
			
			.reduce((content, transformer)->
				lastTransformer = transformer
				flags = extend true, @task.options
				transformOpts = extend {_flags:flags}, transformer.opts
				prevContent = content

				Promise.bind(@)
					.tap ()-> debug "applying transform #{chalk.yellow transformer.name} to #{@pathDebug} (from #{label} transforms)"
					.then ()-> helpers.runTransform(@, content, transformer, transformOpts)
					.then (content)->
						return content if content is prevContent
						if transformer.name.includes(/coffeeify|tsify-transform/)
							@pathExt = 'js'
						else if transformer.name.includes(/csonify|yamlify/)
							@pathExt = 'json'
							content = content.replace /^module\.exports\s*=\s*/, ''
							content = content.slice(0,-1) if content[content.length-1] is ';'
						
						if @pathExt isnt @pathExtOriginal
							@pathAbs = helpers.changeExtension(@pathAbs, @pathExt)
						
						return @sourceMap.update(content)
				
			, content)
			.catch (err)->
				@task.emit 'TransformError', @, err, lastTransformer
				return prevContent

			.tap @timeEnd



	tokenize: ()->
		unless EXTENSIONS.nonJS.includes(@pathExt)
			@timeStart()
			debug "tokenizing #{@pathDebug}"
			tokens = helpers.tokenize(@content)
			
			if tokens instanceof Error
				@task.emit 'TokenizeError', @, tokens
			else
				@Tokens = tokens

			@timeEnd()			

		return @content



	genAST: ()->
		content = if @pathExt is 'json' then "(#{@content})" else @content
		@checkSyntaxErrors(content)
		try
			debug "generating AST #{@pathDebug}"
			@timeStart()
			@AST = Parser.parse(content, range:true, loc:true, comment:true, source:@pathRel, sourceType:'module')
			@timeEnd()
		catch err
			@task.emit 'ASTParseError', @, err

		return content


	genSourceMap: ()->
		if @sourceMap
			return @sourceMap
		
		else if @AST
			@timeStart()
			@sourceMap = JSON.parse Parser.generate(@AST, comment:true, sourceMap:true)
			@timeEnd()
			return @sourceMap


	adjustSourceMap: ()-> if @sourceMap
		return @sourceMap is @contentOriginal is @content
		output = require('inline-source-map')(file:@pathRel)
		mappings = require('combine-source-map/lib/mappings-from-map')(@sourceMap)
		currentOffset = 0
		
		# for mapping in mappings
		# 	mapping


	replaceES6Imports: (save=true)->
		hasImports = false
		newContent = @content.replace REGEX.es6import, (original, meta, defaultMember='', members='', childPath)=>
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
		debug "collecting force inline imports #{@pathDebug}"
		@timeStart()
		@content.replace REGEX.inlineImport, (entire, childPath, offset)=>
			statement = helpers.newImportStatement()
			statement.source = @
			statement.target = helpers.normalizeTargetPath(childPath, @, true)
			statement.offset = 0
			statement.range.start = offset
			statement.range.end = offset + entire.length
			statement.range.length = entire.length
			statement.type = 'inline-forced'
			@inlineStatements.push(statement)
		
		@timeEnd()
		return @inlineStatements


	collectImports: (tokens=@Tokens)->
		debug "collecting imports #{@pathDebug}"
		collected = []
		@timeStart()
		switch
			when tokens
				@collectedImports = true
				
				try
					requires = if @options.skip then [] else helpers.collectRequires(tokens, @contentPostTransforms)
					imports = helpers.collectImports(tokens, @contentPostTransforms)
					statements = imports.concat(requires).sortBy('tokenRange.start')
				catch err
					if err.name is 'TokenError'
						@task.emit('TokenError', @, err)
					else
						@task.emit('GeneralError', @, err)

					return collected


				statements.forEach (statement)=>
					statement.target = helpers.normalizeTargetPath(statement.target, @)
					targetSplit = statement.target.split(REGEX.extractDelim)
					statement.target = targetSplit[0]
					statement.extract = targetSplit[1]
					statement.range.start = tokens[statement.tokenRange.start].start
					statement.range.end = tokens[statement.tokenRange.end].end
					statement.source = @getStatementSource(statement)
					collected.push(statement)



			when @pathExt is 'pug' or @pathExt is 'jade'
				@collectedImports = true
				@content.replace REGEX.pugImport, (entireLine, childPath, offset)=>
					statement = helpers.newImportStatement()
					statement.target = helpers.normalizeTargetPath(childPath, @, true)
					statement.range.start = offset
					statement.range.end = offset + entireLine.length
					statement.type = 'inline'
					statement.source = @getStatementSource(statement)
					collected.push(statement)


			when @pathExt is 'sass' or @pathExt is 'scss'
				@collectedImports = true
				@content.replace REGEX.cssImport, (entireLine, childPath, offset)=>
					statement = helpers.newImportStatement()
					statement.target = helpers.normalizeTargetPath(childPath, @, true)
					statement.range.start = offset
					statement.range.end = offset + entireLine.length
					statement.type = 'inline'
					statement.source = @getStatementSource(statement)
					collected.push(statement)
		

		@timeEnd()
		@statements.push collected...
		return collected


	collectExports: (tokens=@Tokens)->
		debug "collecting exports #{@pathDebug}"
		collected = []
		@timeStart()
		if tokens
			try
				statements = helpers.collectExports(tokens, @contentPostTransforms, @)
			catch err
				if err.name is 'TokenError'
					@task.emit('TokenError', @, err)
				else
					@task.emit('GeneralError', @, err)

				return collected

			statements.forEach (statement)=>
				statement.range = 'start':tokens[statement.tokenRange.start].start, 'end':tokens[statement.tokenRange.end].end
				statement.source = @getStatementSource(statement)
				statement.target ?= @
				if statement.decs
					for dec,range of statement.decs
						throw new Error "#{dec} = #{JSON.stringify range}" if Object.keys(range).length is 1
						statement.decs[dec] = {range, content:@content.slice(range.start, range.end)}

				collected.push(statement)
				@hasDefaultExport = true if statement.default or statement.members?.default


		@timeEnd()
		@statements.push collected...
		return collected



	replaceInlineStatements: ()->
		@timeStart()
		debug "replacing force-inline imports #{@pathDebug}"
		lines = @contentPostConditionals or @content # the latter 2 will be used when type==='inline-forced'

		
		split = helpers.splitContentByStatements(@content, @inlineStatements)
		content = split.reduce (acc, statement)=>
			if typeof statement is 'string'
				return acc+statement
			else
				replacement = @resolveStatementReplacement(statement, {lines})
				index = @inlineStatements.indexOf(statement)
				leadingStatements = @inlineStatements.slice(index)
				leadingStatements.forEach (statement)->
					statement.offset += replacement.length - statement.range.length
				# newRange = helpers.newReplacementRange(statement.range, replacement)
				# replacementRange = @addRangeOffset 'inlines', newRange
				# replacementRange.source = statement.target
				# range = @offsetRange(statement.range, ['inline-forced'], rangeGroup)
				# newRange = helpers.newReplacementRange(range, replacement)
				# @sourceMap.addRange {
				# 	from: {start:0, end:statement.target.contentOriginal.length}
				# 	to: newRange
				# 	file: statement.target
				# 	offset: 0
				# 	name: "#{type}:#{index+1}"
				# 	content
				# }
				return acc+replacement

		@timeEnd()
		return content


	replaceStatements: ()->
		@timeStart()
		debug "replacing imports/exports #{@pathDebug}"

		split = helpers.splitContentByStatements(@content, @statements)
		content = split.reduce (acc, statement, index)=>
			if typeof statement is 'string'
				return acc+statement
			else				
				replacement = @resolveStatementReplacement(statement)
				# @sourceMap.addRange {from:statement.range, to:newRange, name:"#{statement.statementType}:#{index+1}", content}
				return acc+replacement


		@timeEnd()
		return "#{@getExportedFunctions()}#{content}"
	

	extract: (key, returnActual)->
		try
			@timeStart()
			@parsed ?= JSON.parse(@content)
			@timeEnd()
		catch err
			@task.emit 'DataParseError', @, err

		if not @parsed[key] and not Object.has(@parsed, key)
			@task.emit 'ExtractError', @, new Error "requested key '#{key}' not found"
		else
			result = @parsed[key] or Object.get(@parsed, key)
			return result if returnActual
			return JSON.stringify(result)


	resolveStatementReplacement: (statement, {lines, type}={})->
		# type ?= statement.type or statement.statementType
		type ?= if statement.statementType is 'export' then 'export' else statement.type
		lines ?= @contentPostTransforms
		loader = @task.options.loaderName
		lastChar = @content[statement.range.end]
	
		switch type
			when 'inline','inline-forced'
				return '' if statement.excluded
				targetContent = if statement.extract then statement.target.extract(statement.extract) else statement.target.content
				targetContent = helpers.prepareMultilineReplacement(@content, targetContent, lines, statement.range)
				targetContent = '{}' if not targetContent

				if EXTENSIONS.compat.includes(statement.target.pathExt)
					lastChar = @content[statement.range.end]
					targetContent = "(#{targetContent})" if lastChar is '.' or lastChar is '('

				return targetContent



			when 'module' # regular import
				return "require('#{statement.target}')" if statement.excluded
				if not statement.members and not statement.alias # commonJS import / side-effects es6 import
					replacement = "#{loader}(#{statement.target.IDstr})"
					if statement.extract
						replacement += "['#{statement.extract}']"
					
					else if statement.target.hasDefaultExport and @options.extractDefaults
						replacement = "#{replacement} ? #{replacement}.default : #{replacement}"
						replacement = "(#{replacement})" if lastChar is '.' or lastChar is '('

				else
					alias = statement.alias or helpers.strToVar(statement.target.pathName)
					replacement = "var #{alias} = #{loader}(#{statement.target.IDstr})"

					if statement.members
						nonDefault = Object.exclude(statement.members, (k,v)-> v is 'default')
						decs = []
						
						if statement.members.default
							if statement.target.hasDefaultExport and @options.extractDefaults
								decs.push("#{statement.members.default} = #{alias}.default")
							else
								decs.push("#{statement.members.default} = #{alias}")

						decs.push("#{keyAlias} = #{alias}.#{key}") for key,keyAlias of nonDefault
						replacement += ", #{decs.join ', '};"

				
				return helpers.prepareMultilineReplacement(@content, replacement, lines, statement.range)



			when 'export'
				replacement = ''
			
				if statement.target isnt statement.source
					alias = helpers.strToVar(statement.target.pathName)
					replacement = "var #{alias} = #{loader}(#{statement.target.IDstr})\n"

					if statement.members
						decs = []
						decs.push("exports.#{keyAlias} = #{alias}.#{key}") for keyAlias,key of statement.members
						replacement += decs.join ', '
					
					else
						key = helpers.strToVar(statement.target.pathName)
						replacement += "var #{key}; for (#{key} in #{alias}) exports[#{key}] = #{alias}[#{key}];"


				else
					if statement.members
						decs = []
						decs.push("exports.#{keyAlias} = #{key}") for keyAlias,key of statement.members
						replacement += decs.join ', '
					

					else if statement.decs
						for nested in statement.nestedStatements
							targetDec = statement.decs[nested.dec]
							targetDec.content =
								targetDec.content.slice(0, nested.range.start) +
								@resolveStatementReplacement(nested.statement) +
								targetDec.content.slice(nested.range.end)

						decs = Object.keys(statement.decs)
						values = Object.values(statement.decs)

						replacement += "#{statement.keyword} #{values.map('content').join ', '}\n"
						replacement += "exports.#{dec} = #{dec}; " for dec in decs


					else
						if statement.keyword isnt 'function' or not statement.identifier
							if statement.default
								replacement += "exports.default = "
								replacement += statement.identifier if statement.identifier and not statement.keyword # assignment-expr-left
							
							else if statement.identifier
								replacement += "exports.#{statement.identifier} = "

						if statement.keyword# and not isDec # function or class
							replacement += "#{statement.keyword} "
							if statement.identifier
								replacement = "#{replacement} #{statement.identifier}"
				

				return helpers.prepareMultilineReplacement(@content, replacement, lines, statement.range)


	getStatementSource: (statement)->
		range = statement.range
		
		for candidate,i in @inlineStatements when not candidate.excluded
			offset = candidate.offset
			candidateRange = candidate.range
			candidateRange = start:candidateRange.start+offset, end:candidateRange.end+offset
			
			if candidateRange.start <= statement.range.start and statement.range.end <= candidateRange.end
				statement.range.orig = candidate
				return candidate.target.getStatementSource(statement)
		
		return @


	getExportedFunctions: ()->
		exportedFunctions = @statements
			.filter (statement)-> statement.statementType is 'export' and statement.keyword is 'function' and statement.identifier
			.map (statement)->
				targetExport = if statement.default then 'default' else statement.identifier
				"exports.#{targetExport} = #{statement.identifier};"
			.join '\n'

		if exportedFunctions then exportedFunctions+'\n' else ''


	offsetStatements: (offset)->
		for statement in @statements
			if statement.range.start >= offset.start
				length = offset.end - offset.start
				statement.range.start += length
				statement.range.end += length
		return

	resolveNestedStatements: ()->
		exportStatements = @statements.filter({statementType:'export'})
		importStatements = @statements.filter({statementType:'import'})
		for statement in importStatements
			statement.isNested = helpers.matchNestingStatement(statement, exportStatements)
		return



	destroy: ()->
		@statements.length = 0
		@inlineStatements.length = 0
		@conditionals.length = 0
		@tokens?.length = 0
		delete @ID
		delete @AST
		delete @tokens
		delete @statements
		delete @inlineStatements
		delete @conditionals
		delete @requiredGlobals
		delete @parsed
		delete @options
		delete @linesPostTransforms
		delete @linesPostConditionals
		delete @linesOriginal
		delete @pkgTransform
		delete @task
		for prop of @ when prop.startsWith('content') or prop.startsWith('file')
			delete @[prop] if @hasOwnProperty(prop)


		return









module.exports = File