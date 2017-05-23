Promise = require 'bluebird'
promiseBreak = require 'p-break'
replaceAsync = require 'string-replace-async'
streamify = require 'streamify-string'
getStream = require 'get-stream'
PATH = require 'path'
chalk = require 'chalk'
extend = require 'extend'
globMatch = require 'micromatch'
Parser = require 'esprima'
REGEX = require './regex'
helpers = require './helpers'
consoleLabels = require './consoleLabels'


class File
	constructor: (@task, state)->
		extend(@, state)
		@importedCount = 0
		@imports = []
		@importStatements = custom:[], es6:[]
		@badImports = []
		@importMemberRefs = []
		@lineRefs = []
		@orderRefs = []
		@ignoreRanges = []
		@contentOriginal = @content
		@contentLines = @content.split(REGEX.newLine)
		@ID = ++@task.currentID
		
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
			REGEX.commonJS.validRequire.test(@content)


	collectRequiredGlobals: ()-> if not @isThirdPartyBundle
		@task.emit('requiredGlobal', 'global') if REGEX.vars.global.test(@content) and not REGEX.globalCheck.test(@content)
		@task.emit('requiredGlobal', 'process') if REGEX.vars.process.test(@content) and not REGEX.processRequire.test(@content) and not REGEX.processDec.test(@content)
		@task.emit('requiredGlobal', '__dirname') if REGEX.vars.__dirname.test(@content)
		@task.emit('requiredGlobal', '__filename') if REGEX.vars.__filename.test(@content)
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


	findCustomImports: ()->
		@content.replace REGEX.customImport, (entireLine, priorContent='', importKeyword, conditions='', whitespace='', childPath, trailingContent='', offset)->
			statement = {range:[], source:@}
			statement.conditions = conditions.split(REGEX.commaSeparated)
			statement.target = helpers.cleanImportPath(childPath)
			statement.extract = statement.target.split('$')[1]
			statement.target = statement.target.split('$')[0] if statement.extract
			statement.range[0] = offset + priorContent.length
			statement.range[1] = statement.range[0] + importKeyword.length + (if conditions then 2 else 0) + whitespace.length + childPath.length
			
			@importStatements.custom.push(statement)


	findES6Imports: ()->
		@content.replace REGEX.es6Import, (entireLine, importKeyword, metadata, defaultMember='', members='', childPath, offset)->
			statement = {range:[], source:@}
			statement.members = if members then helpers.parseMembersString(members)
			statement.defaultMember = defaultMember
			statement.target = helpers.cleanImportPath(childPath)
			statement.range[0] = offset
			statement.range[1] = offset + entireLine.length
			
			@importStatements.es6.push(statement)


	customImportsToCommonJS: ()->
		for statement in @importStatements.custom
			body = "'#{statement.target}'"
			body += ", [#{statement.conditions.map((i)-> '"'+i+'"').join(',')}]"
			commonSyntax = "require(#{body})"
			@content = @content.slice(0,statement.range[0]) + commonSyntax + @content.slice(statement.range[1])
			statement.range[1] = statement.range[0] + commonSyntax.length # Update end offset of range

		return


	ES6ImportsToCommonJS: ()->
		for statement in @importStatements.es6
			body = "'#{statement.target}', null"
			body += ", #{if statement.defaultMember then '"'+statement.defaultMember+'"' else 'null'}"
			body += ", #{if statement.members then JSON.stringify(statement.members) else 'null'}"
			commonSyntax = "require(#{body})"
			@content = @content.slice(0,statement.range[0]) + commonSyntax + @content.slice(statement.range[1])
			statement.range[1] = statement.range[0] + commonSyntax.length # Update end offset of range

		return


	applySpecificTransforms: ()->
		Promise.bind(@)
			.then ()->
				transforms = @options.transform or []
				transforms.unshift('tsify') if @fileExt is 'tn' and not transforms.includes('tsify')
				transforms.unshift('coffeeify') if @fileExt is 'coffee' and not transforms.includes('coffeeify')
				promiseBreak(@content) if not transforms.length
			
			.then (transforms)->
				@applyTransforms(@content, transforms, PATH.resolve(@pkgFile.dirPath,'node_modules'))

			.catch promiseBreak.end
			.then (@content)->


	applyPkgTransforms: ()->
		Promise.resolve(@pkgTransform).bind(@)
			.filter (transform)->
				name = if typeof transform is 'string' then transform else transform[0]
				return name.toLowerCase() isnt 'simplyimportify'

			.then (transforms)->
				@applyTransforms(@content, transforms, PATH.resolve(@pkgFile.dirPath,'node_modules'))

			.then (@content)->


	applyGlobalTransforms: ()->
		Promise.bind(@)
			.then ()->
				transforms = @task.options.globalTransform
				promiseBreak(@content) if not transforms?.length
			
			.then (transforms)->
				@applyTransforms(@content, transforms, PATH.resolve(@pkgFile.dirPath,'node_modules'))

			.catch promiseBreak.end
			.then (@content)->



	applyTransforms: (content, transforms, useFullPath)->
		Promise.resolve(transforms)
			.map (transform)-> helpers.resolveTransformer(transform, useFullPath)
			.reduce((content, transformer)=>
				filePath = if useFullPath then @filePath else PATH.basename(@filePath)
				transformOpts = extend {_flags:@task.options}, transformer.opts
			
				Promise.resolve()
					.then ()-> getStream streamify(content).pipe(transformer.fn(filePath, transformOpts))
					.tap ()=>
						if transformer.name is 'coffeeify' or transformer.name is 'tsify'
							@fileExt = 'js'
							@filePath = helpers.changeExtension(@filePath, 'js')
							@filePathSimple = helpers.changeExtension(@filePathSimple, 'js')
				
			, content)



	genAST: ()->
		canGenAST = @fileExt is 'js' and (
			@importStatements.custom.length or
			@importStatements.es6.length or
			REGEX.export.test(@content) or
			REGEX.commonJS.export.test(@content)
		)
		
		if canGenAST
			try
				@ast = Parser.parse(@content, tolerant:true)
			catch err
				@task.emit 'parseError', @, err







	# checkIfImportsFile: (targetFile)->
	# 	iteratedArrays = [@imports]
	# 	importRefs = @task.importRefs
		
	# 	checkArray = (importsArray)->
	# 		importsArray.includes(targetFile.hash) or
	# 		importsArray.find (importHash)->
	# 			currentFile = importRefs[importHash]
	# 			### istanbul ignore else ###
	# 			if currentFile
	# 				if iteratedArrays.includes(currentFile.imports)
	# 					return false
	# 				else
	# 					iteratedArrays.push(currentFile.imports)
	# 					return checkArray(currentFile.imports)

	# 	checkArray(@imports)



	# addLineRef: (entireLine, targetRef, offset=0)->
	# 	lineIndex = @contentLines.indexOf(entireLine, offset)
	# 	existingRef = @lineRefs.findIndex (existingLineRef)-> existingLineRef is lineIndex

	# 	if existingRef >= 0
	# 		@addLineRef(entireLine, targetRef, lineIndex+1)
	# 	else
	# 		@lineRefs[targetRef] = lineIndex


	# processImport: (childPath, entireLine, priorContent, spacing, conditions='', defaultMember='', members='')->
	# 	entireLine = entireLine.replace REGEX.startingNewLine, ''
	# 	orderRefIndex = @orderRefs.push(entireLine)-1
	# 	childPath = origChildPath = childPath
	# 		.replace /['"]/g, '' # Remove quotes form pathname
	# 		.replace /[;\s]+$/, '' # Remove whitespace from the end of the string

	# 	Promise.bind(@)
	# 		.then ()-> helpers.resolveModulePath(childPath, @context, @filePath, @pkgFile)
	# 		.then (module)->
	# 			childPath = module.file
	# 			pkgFile = module.pkg or @pkgFile

			
	# 			switch
	# 				when helpers.testForComments(entireLine, @isCoffee) or helpers.testForOuterString(entireLine) or helpers.isCoreModule(origChildPath)
	# 					Promise.resolve()
				
	# 				when not helpers.testConditions(@task.options.conditions, conditions)
	# 					@badImports.push(childPath)
	# 					@addLineRef(entireLine, 'bad_'+(@badImports.length-1))
	# 					Promise.resolve()
				
	# 				else
	# 					childFile = new File childPath, @task.options, @task.importRefs, {'suppliedPath':origChildPath, pkgFile}
	# 					childFile.process()
	# 						.then (childFile)=> # Use the returned instance as it may be a cached version diff from the created instance
	# 							childFile.importedCount++ unless module.isEmpty
	# 							@task.importRefs[childFile.hash] = childFile
	# 							@imports[orderRefIndex] = childFile.hash
	# 							@orderRefs[orderRefIndex] = childFile.hash
	# 							@addLineRef(entireLine, orderRefIndex)

	# 							if defaultMember or members
	# 								@importMemberRefs[orderRefIndex] = default:defaultMember, members:helpers.parseMembersString(members)
	# 								childFile.hasUsefulExports = true
								
	# 							if priorContent and not module.isEmpty
	# 								childFile.requiresReturnedClosure = /\S/.test(priorContent)

	# 							Promise.resolve()

	# 						.catch (err)=>
	# 							if @task.options.recursive # If false then it means this is just a scan from the entry file so ENONET errors are meaningless to us
	# 								selfReference = @filePathSimple+':'+(@contentLines.indexOf(entireLine)+1)
	# 								console.error "#{consoleLabels.error} File/module doesn't exist '#{origChildPath}' #{chalk.dim(selfReference)}"
	# 								Promise.reject(err)



	# collectImports: ()-> if @collectedImports then @collectedImports else
	# 	if @options.scan is false
	# 		return @collectedImports = Promise.resolve()
		
	# 	@collectedImports = Promise.resolve()
	# 		.then ()=>
	# 			if @requiredGlobals.includes('process')
	# 				declaration = if @isCoffee then 'process' else 'var process'
	# 				assignment = "#{declaration} = require('process');"
	# 				@content = "#{assignment}\n#{@content}"
	# 				@contentLines.unshift(assignment)
			
	# 		.then ()=>
	# 			replaceAsync.seq @content, REGEX.import, (entireLine, priorContent, spacing, conditions, defaultMember, members, childPath)=>
	# 				if helpers.testIfIsIgnored @ignoreRanges, Array::slice.call(arguments, -2)[0]
	# 					Promise.resolve()
	# 				else
	# 					@processImport(childPath, entireLine, priorContent, spacing, conditions, defaultMember, members)


	# 		.then ()=> unless @isThirdPartyBundle
	# 			replaceAsync.seq @content, REGEX.commonJS.import, (entireLine, priorContent, bracketOrSpace, childPath, trailingContent)=>
	# 				if not REGEX.commonJS.validRequire.test(entireLine) and not @isCoffee
	# 					Promise.resolve()
	# 				else
	# 					if helpers.testIfIsIgnored @ignoreRanges, Array::slice.call(arguments, -2)[0]
	# 						Promise.resolve()
	# 					else
	# 						@processImport(childPath, entireLine, priorContent)
	# 				# If the trailing content has a closing bracket w/out an opening then it means the 'childPath'
	# 				# is some sort of an expression (i.e. "'st'+'ing'" or "'string'+suffix") which is currently
	# 				# unsupported and means the childPath wasn't fully captured


	# 	@collectedImports
	# 		.then ()=>
	# 			if REGEX.export.test(@content) or REGEX.commonJS.export.test(@content) or REGEX.vars.exports.test(@content)
	# 				@hasExports = true unless @hasThirdPartyRequire or @isEntry
	# 				@normalizeExports()	unless @isThirdPartyBundle

	# 		.then ()=>
	# 			if @task.options.recursive
	# 				Promise.all(@imports
	# 					.map (childFileHash)=> @task.importRefs[childFileHash]
	# 					.filter (file)=> not file.checkIfImportsFile(@)
	# 					.map (file)-> file.collectImports()
	# 				)



	# normalizeExports: ()->
	# 	# ==== CommonJS syntax =================================================================================
	# 	@content.replace REGEX.commonJS.export, (entireLine, priorContent, operator, trailingContent)=>
	# 		operator = " #{operator}" if operator is '='
	# 		lineIndex = @contentLines.indexOf(entireLine)
	# 		@contentLines[lineIndex] = "#{priorContent}module.exports#{operator}#{trailingContent}"


	# 	# ==== ES6/SimplyImport syntax =================================================================================
	# 	@content.replace REGEX.export, (entireLine, exportMap, exportType, label, trailingContent)=>
	# 		lineIndex = @contentLines.indexOf(entireLine)
	# 		switch
	# 			when exportMap
	# 				@contentLines[lineIndex] = "module.exports = #{helpers.normalizeExportMap(exportMap)}#{trailingContent}"
				
	# 			when exportType is 'default' then return switch
	# 				when helpers.testIfIsExportMap(label+trailingContent)
	# 					exportMap = label+trailingContent.replace(/;$/, '')
	# 					@contentLines[lineIndex] = "module.exports['*default*'] = #{helpers.normalizeExportMap(exportMap)}"
	# 				else
	# 					@contentLines[lineIndex] = "module.exports['*default*'] = #{label}#{trailingContent}"
				
	# 			when exportType?.includes('function')
	# 				labelName = label.replace(/\(.*?\).*$/, '')
	# 				### istanbul ignore next ###
	# 				value = if trailingContent.includes('=>') then "#{label}#{trailingContent}" else "#{exportType} #{label}#{trailingContent}"
	# 				@contentLines[lineIndex] = "module.exports['#{labelName}'] = #{value}"

	# 			when exportType is 'class'
	# 					@contentLines[lineIndex] = "module.exports['#{label}'] = #{exportType} #{label}#{trailingContent}"

	# 			when exportType
	# 					declaration = if @isCoffee then '' else "#{exportType} "
	# 					@contentLines[lineIndex] = "#{declaration}#{label} = module.exports['#{label}'] = #{trailingContent.replace(/^\s*\=\s*/, '')}"

	# 			when not exportType and not exportMap
	# 				label = trailingContent.match(/^\S+/)[0]
	# 				@contentLines[lineIndex] = "module.exports['#{label}'] = #{trailingContent}"
	# 			# else
	# 			# 	throw new Error "Cannot figure out a way to parse the following ES6 export statement: (line:#{lineIndex+1}) #{entireLine}"



	# replaceImports: (childImports)->
	# 	@imports.forEach (childHash, importIndex)=>
	# 		childFile = @task.importRefs[childHash]
	# 		childContent = childFile.compiledContent
	# 		targetLine = @lineRefs[importIndex]

	# 		replaceLine = (childPath, entireLine, priorContent, trailingContent, spacing, conditions, defaultMember, members)=>
	# 			if childFile.importedCount > 1 or childFile.hasExports
	# 				childContent = "_s$m(#{childFile.ID})"
	# 			else
	# 				# ==== JS vs. Coffeescript conflicts =================================================================================
	# 				switch
	# 					when @isCoffee and not childFile.isCoffee
	# 						childContent = helpers.formatJsContentForCoffee(childContent)
						

	# 					when not @isCoffee and childFile.isCoffee and childFile.content
	# 						if @task.options.compileCoffeeChildren
	# 							childContent = coffeeCompiler.compile childContent, 'bare':true
	# 						else
	# 							selfReference = @filePathSimple+':'+(@contentLines.indexOf(entireLine)+1)
	# 							throw new Error "
	# 								#{chalk.dim(selfReference)}: 
	# 								You're attempting to import a CoffeeScript file (#{chalk.dim(childFile.filePathSimple)})
	# 								into a JS file (which will provide a broken file), rerun this import with -C or --compile-coffee-children
	# 							"



	# 			# ==== Handle Parenthesis =================================================================================
	# 			if trailingContent.startsWith(')')
	# 				if priorContent
	# 					spacing += '(' unless priorContent.includes('(')
	# 				else
	# 					priorContent = '('
	# 					spacing = ''

	# 			# ==== Extract exports =================================================================================
	# 			if childFile.hasUsefulExports and importData=@importMemberRefs[importIndex]
	# 				@requiresClosure = true
	# 				varPrefix = if @isCoffee then '' else 'var '
	# 				members = Object.keys importData.members
	# 				tempName = helpers.genUniqueVar()
	# 				tempNameDeclaration = "#{varPrefix}#{tempName} = #{childContent};\n"
	# 				childContentRef = tempName

	# 				switch
	# 					when importData.default
	# 						childContent = tempNameDeclaration
	# 						childContent += "#{varPrefix}#{importData.default} = #{childContentRef}['*default*'];\n"
						
	# 					when members.length
	# 						if members.length is 1 and members[0] is '!*!'
	# 							childContentRef = childContent
	# 							childContent = '' # Since a copy is saved in childContentRef and it will be appended to this var via += when adding the members below
	# 						else
	# 							childContent = tempNameDeclaration

					
	# 				for key,alias of importData.members
	# 					if key is '!*!'
	# 						childContent += "#{varPrefix}#{alias} = #{childContentRef};\n"
	# 					else
	# 						childContent += "#{varPrefix}#{alias} = #{childContentRef}['#{key}'];\n"


	# 			# ==== Spacing =================================================================================
	# 			if priorContent and priorContent.replace(/\s/g, '') is ''
	# 				spacing = priorContent+spacing
	# 				priorContent = ''

	# 			if spacing and not priorContent
	# 				childContent = helpers.addSpacingToString(childContent, spacing)

	# 			if priorContent and childContent
	# 				if priorContentSpacing = priorContent.match(REGEX.initialWhitespace)?[0]
	# 					childContent = helpers.addSpacingToString(childContent, priorContentSpacing, 1)
					
	# 				childContent = priorContent + spacing + childContent

	# 			return childContent+trailingContent
			


	# 		if REGEX.import.test(@contentLines[targetLine])
	# 			@contentLines[targetLine] = @contentLines[targetLine].replace REGEX.import, (entireLine, priorContent, spacing, conditions, defaultMember, members, childPath, trailingContent)->
	# 				replaceLine(childPath, entireLine, priorContent, trailingContent, spacing, conditions, defaultMember, members)
	# 		else
	# 			@contentLines[targetLine] = @contentLines[targetLine].replace REGEX.commonJS.import, (entireLine, priorContent, bracketOrSpace, childPath, trailingContent)->
	# 				replaceLine(childPath, entireLine, priorContent, trailingContent, '')

	# 	return




	# replaceBadImports: ()->
	# 	for badImport,index in @badImports
	# 		targetLine = @lineRefs['bad_'+index]

	# 		if @task.options.preserve
	# 			@contentLines[targetLine] = helpers.commentOut(@contentLines[targetLine], @isCoffee)
	# 		else
	# 			@contentLines.splice(targetLine, 1)




	# prependDuplicateRefs: (content)->
	# 	duplicates = (file for hash,file of @task.importRefs when file.importedCount > 1 or file.hasExports)
	# 	return content if not duplicates.length

	# 	Promise
	# 		.all duplicates.map (file)-> file.compile()
	# 		.then ()=>
	# 			assignments = []
				
	# 			for file in duplicates
	# 				value = if @isCoffee and not file.isCoffee
	# 							helpers.formatJsContentForCoffee(file.compiledContent)
	# 						else
	# 							file.compiledContent

	# 				assignments.push "m[#{file.ID}] = #{value}"

	# 			loader = helpers.wrapInLoaderClosure(assignments, '\t', @isCoffee)
	# 			result = "#{loader}\n#{content}"
	# 			result = if @task.options.preventGlobalLeaks then helpers.wrapInClosure(result, @isCoffee, false, '') else result
	# 			return result



	# compile: (importerStack=[])-> if @compilePromise then @compilePromise else
	# 	return (@compiledContent=@content) if not @task.options.recursive and not @isEntry
	# 	### istanbul ignore next ###
	# 	importerStack.push(@) unless importerStack.includes(@)

	# 	childImportsPromise = Promise.delay().then ()=>
	# 		Promise.all @imports.map (hash)=>
	# 			childFile = @task.importRefs[hash]
	# 			childFile.compile(importerStack) unless importerStack.includes(childFile) and childFile.imports.length

			
	# 	@compilePromise = childImportsPromise
	# 		.then (childImports)=>
	# 			@replaceImports(childImports)
	# 			@replaceBadImports(childImports)
	# 			return @contentLines.join '\n'

	# 		.then (compiledResult)=>
	# 			if @requiredGlobals.length and not @isThirdPartyBundle
	# 				helpers.wrapInGlobalsClosure(compiledResult, @)
	# 			else
	# 				compiledResult

	# 		.then (compiledResult)=>
	# 			if not @isEntry and @pkgTransform?.length
	# 				@applyPkgTransforms(compiledResult)
	# 			else
	# 				compiledResult

	# 		.then (compiledResult)=>
	# 			if @isEntry and @task.options.transform.length
	# 				@applyTransforms(compiledResult, @task.options.transform)

	# 			else if not @isEntry and @task.options.globalTransform.length
	# 				@applyTransforms(compiledResult, @task.options.globalTransform)			
				
	# 			else
	# 				compiledResult
			
	# 		.then (compiledResult)=>
	# 			if @options.transform
	# 				@applyTransforms(compiledResult, @options.transform)
	# 			else
	# 				compiledResult

	# 		.then (compiledResult)=>
	# 			switch
	# 				when @isEntry
	# 					return @prependDuplicateRefs(compiledResult)
					
	# 				when @hasExports
	# 					return helpers.wrapInExportsClosure(compiledResult, @isCoffee, true, @debugRef)
					
	# 				when @requiresReturnedClosure or @importedCount>1
	# 					if @isCoffee
	# 						if @importedCount is 1 and helpers.testIfCoffeeIsExpression(compiledResult)
	# 							return compiledResult
	# 						else
	# 							return helpers.wrapInClosure(compiledResult, @isCoffee, @importedCount>1, @debugRef)
	# 					else
	# 						modifiedContent = helpers.modToReturnLastStatement(compiledResult, @filePathSimple)
							
	# 						if modifiedContent is false
	# 							return compiledResult
						
	# 						if modifiedContent is 'ExpressionStatement'
	# 							return compiledResult unless @importedCount>1
	# 							modifiedContent = "return #{compiledResult}"
							
	# 						return helpers.wrapInClosure(modifiedContent, false, @importedCount>1, @debugRef)
	# 					### istanbul ignore next ###
					
	# 				when @requiresClosure
	# 					return helpers.wrapInClosure(compiledResult, @isCoffee, @importedCount>1, @debugRef)

	# 				else compiledResult
			
			
	# 		.then (result)=> @compiledContent = result or '{}'









module.exports = File