Promise = require 'bluebird'
fs = Promise.promisifyAll require 'fs-extra'
replaceAsync = require 'string-replace-async'
md5 = require 'md5'
PATH = require 'path'
chalk = require 'chalk'
coffeeCompiler = require 'coffee-script'
uglifier = require 'uglify-js'
regEx = require './regex'
helpers = require './helpers'
consoleLabels = require './consoleLabels'
allowedExtensions = ['js','ts','coffee','sass','scss','css','html','jade','pug']


###*
 * The object created for each file path the program needs to open/import/read.
 * @param {String} input               	File's path or file's contents
 * @param {Object} state	          	(optional) initial state map to indicate if 'isStream', 'isCoffee', and 'context'
 * @param {Object} importHistory	 	(optional) the import history collected so far since the main faile import
###
File = (input, @options, @importRefs, {@isMain, @isCoffee, @context}={})->
	@input = input
	@importedCount = 0
	@imports = []
	@badImports = []
	@importMemberRefs = []
	@lineRefs = []
	@orderRefs = []
	@contentReference = @getID()
	@cacheRef = if @isMain then '*MAIN*' else input
	@importRefs.main = @ if @isMain

	return File.instanceCache[@cacheRef] or @


File::getID = ()->
	if @isMain
		@currentID = 0
	else
		@importRefs.main.currentID += 1


File::process = ()-> if @processPromise then @processPromise else
	@processPromise = Promise.bind(@)
		.then(@getFilePath)
		.then(@getSimpleFilePath)
		.then(@resolveContext)
		.then(@checkIfIsCoffee)
		.then(@getContents)
		.then(@checkIfIsThirdPartyBundle)
		.then ()=>
			unless @isMain
				if File.instanceCache[@hash] and not File.instanceCache[@cacheRef]
					File.instanceCache[@cacheRef] = File.instanceCache[@hash]
				else
					File.instanceCache[@hash] = @

			return File.instanceCache[@cacheRef] ||= @
		


File::getContents = ()->
	if @isMain
		@contentLines = @input.split(regEx.newLine)
		@hash = md5(@input)
		return @content = @input
	else
		fs.readFileAsync(@filePath, encoding:'utf8').then (content)=>
			@content = content
			@hash = md5(content)
			@contentLines = content.split(regEx.newLine)
			return content



File::getFilePath = ()->
	if @isMain
		return @context
	else
		extname = PATH.extname(@input).slice(1).toLowerCase()
		if extname and allowedExtensions.includes(extname)
			return @filePath = @input
		
		inputFileName = PATH.basename(@input)
		parentDir = PATH.dirname(@input)
		helpers.getDirListing(parentDir, @options.dirCache).then (parentDirListing)=>
			inputPathMatches = parentDirListing.filter (targetPath)-> targetPath.includes(inputFileName)

			if not inputPathMatches.length
				return @filePath = @input
			else
				exactMatch = inputPathMatches.find (targetPath)-> targetPath is inputFileName
				fileMatch = inputPathMatches.find (targetPath)->
					fileNameSplit = targetPath.replace(inputFileName, '').split('.')
					return !fileNameSplit[0] and fileNameSplit.length is 2 # Ensures the path is not a dir and is exactly the inputPath+extname


				if fileMatch
					return @filePath = PATH.join parentDir, fileMatch
				
				else #if exactMatch
					resolvedPath = PATH.join parentDir, inputFileName
					
					fs.statAsync(resolvedPath).then (pathStats)=>
						if not pathStats.isDirectory()
							return @filePath = resolvedPath
						else
							helpers.getDirListing(resolvedPath, @options.dirCache).then (targetDirListing)=>
								indexFile = targetDirListing.find (file)-> file.includes('index')

								if indexFile
									return @filePath = PATH.join parentDir, inputFileName, indexFile
								else
									return @filePath = PATH.join parentDir, inputFileName, 'index.js'



File::getSimpleFilePath = ()->
	if @filePath
		@filePathSimple = helpers.simplifyPath @filePath
	else
		@filePathSimple = '*MAIN*'


File::resolveContext = ()->
	if @isMain then @context else @context = helpers.getNormalizedDirname(@filePath)


File::checkIfIsCoffee = ()->
	@isCoffee = if @isMain then @isCoffee else PATH.extname(@filePath).toLowerCase().slice(1) is 'coffee'


File::checkIfIsThirdPartyBundle = ()->
	### istanbul ignore next ###
	@isThirdPartyBundle =
		@content.includes('.code="MODULE_NOT_FOUND"') or
		@content.includes('__webpack_require__') or
		@content.includes('System.register') or 
		@content.includes("typeof module ===") or
		@content.includes("typeof module !==") or
		@content.includes("typeof define === 'function'") or 
		@content.includes("typeof define === \"function\"") or 
		@content.includes("typeof require === 'function'") or 
		@content.includes("typeof require === \"function\"") or 
		@content.includes("' has not been defined'")

	@hasThirdPartyRequire = @isThirdPartyBundle and
		not regEx.requireArg.test(@content) and
		regEx.commonJS.validRequire.test(@content)


File::checkIfImportsFile = (targetFile)->
	iteratedArrays = [@imports]
	importRefs = @importRefs
	
	checkArray = (importsArray)=>
		importsArray.includes(targetFile.hash) or
		importsArray.find (importHash)->
			currentFile = importRefs[importHash]
			if currentFile
				if iteratedArrays.includes(currentFile.imports)
					return false
				else
					iteratedArrays.push(currentFile.imports)
					return checkArray(currentFile.imports)

	checkArray(@imports)

	


File::addLineRef = (entireLine, targetRef, offset=0)->
	lineIndex = @contentLines.indexOf(entireLine, offset)
	existingRef = @lineRefs.findIndex (existingLineRef)-> existingLineRef is lineIndex

	if existingRef >= 0
		@addLineRef(entireLine, targetRef, lineIndex+1)
	else
		@lineRefs[targetRef] = lineIndex


File::processImport = (childPath, entireLine, priorContent, spacing, conditions='', defaultMember='', members='')->
	entireLine = entireLine.replace regEx.startingNewLine, ''
	orderRefIndex = @orderRefs.push(entireLine)-1
	childPath = origChildPath = childPath
		.replace /['"]/g, '' # Remove quotes form pathname
		.replace /[;\s]+$/, '' # Remove whitespace from the end of the string

	helpers.resolveModulePath(childPath, @context).then (modulePath)=>
		childPath = modulePath or PATH.resolve(@context, childPath)

		if helpers.testForComments(entireLine, @isCoffee) or helpers.testForOuterString(entireLine) or helpers.isCoreModule(origChildPath)
			Promise.resolve()
		
		else if not helpers.testConditions(@options.conditions, conditions)
			@badImports.push(childPath)
			@addLineRef(entireLine, 'bad_'+(@badImports.length-1))
			Promise.resolve()
		
		else
			childFile = new File childPath, @options, @importRefs
			childFile.process()
				.then (childFile)=> # Use the returned instance as it may be a cached version diff from the created instance
					childFile.importedCount++
					@importRefs[childFile.hash] = childFile
					@imports[orderRefIndex] = childFile.hash
					@orderRefs[orderRefIndex] = childFile.hash
					@addLineRef(entireLine, orderRefIndex)

					if defaultMember or members
						@importMemberRefs[orderRefIndex] = default:defaultMember, members:helpers.parseMembersString(members)
						childFile.hasUsefulExports = true
					
					if priorContent
						childFile.requiresReturnedClosure = /\S/.test(priorContent)

					Promise.resolve()

				.catch (err)=>
					if @options.recursive # If false then it means this is just a scan from the entry file so ENONET errors are meaningless to us
						selfReference = @filePathSimple+':'+@contentLines.indexOf(entireLine)
						console.error "#{consoleLabels.error} File/module doesn't exist #{childFile.filePathSimple} #{chalk.dim(selfReference)}"
						Promise.reject(err)



File::collectImports = ()-> if @collectedImports then @collectedImports else
	@collectedImports = Promise.resolve()
		.then ()=>
			replaceAsync.seq @content, regEx.import, (entireLine, priorContent, spacing, conditions, defaultMember, members, childPath)=>
				@processImport(childPath, entireLine, priorContent, spacing, conditions, defaultMember, members)

		.then ()=> unless @isThirdPartyBundle
			replaceAsync.seq @content, regEx.commonJS.import, (entireLine, priorContent, bracketOrSpace, childPath, trailingContent)=>
				if not regEx.commonJS.validRequire.test(entireLine) and not @isCoffee
					Promise.resolve()
				else
					@processImport(childPath, entireLine, priorContent)
				# If the trailing content has a closing bracket w/out an opening then it means the 'childPath'
				# is some sort of an expression (i.e. "'st'+'ing'" or "'string'+suffix") which is currently
				# unsupported and means the childPath wasn't fully captured


	@collectedImports
		.then ()=>
			if regEx.export.test(@content) or regEx.commonJS.export.test(@content) or regEx.exportsVar.test(@content)
				@hasExports = true unless @hasThirdPartyRequire
				@normalizeExports()	unless @isThirdPartyBundle

		.then ()=>
			if @options.recursive
				Promise.all(@imports
					.map (childFileHash)=> @importRefs[childFileHash]
					.filter (file)=> not file.checkIfImportsFile(@)
					.map (file)-> file.collectImports()
				)



File::normalizeExports = ()->
	# ==== CommonJS syntax =================================================================================
	@content.replace regEx.commonJS.export, (entireLine, priorContent, operator, trailingContent)=>
		operator = " #{operator}" if operator is '='
		lineIndex = @contentLines.indexOf(entireLine)
		@contentLines[lineIndex] = "#{priorContent}module.exports#{operator}#{trailingContent}"


	# ==== ES6/SimplyImport syntax =================================================================================
	@content.replace regEx.export, (entireLine, exportMap, exportType, label, trailingContent)=>
		lineIndex = @contentLines.indexOf(entireLine)
		switch
			when exportMap
				@contentLines[lineIndex] = "module.exports = #{helpers.normalizeExportMap(exportMap)}#{trailingContent}"
			
			when exportType is 'default' then return switch
				when helpers.testIfIsExportMap(label+trailingContent)
					exportMap = label+trailingContent.replace(/;$/, '')
					@contentLines[lineIndex] = "module.exports['*default*'] = #{helpers.normalizeExportMap(exportMap)}"
				else
					@contentLines[lineIndex] = "module.exports['*default*'] = #{label}#{trailingContent}"
			
			when exportType?.includes('function')
				labelName = label.replace(/\(.*?\).*$/, '')
				### istanbul ignore next ###
				value = if trailingContent.includes('=>') then "#{label}#{trailingContent}" else "#{exportType} #{label}#{trailingContent}"
				@contentLines[lineIndex] = "module.exports['#{labelName}'] = #{value}"

			when exportType is 'class'
					@contentLines[lineIndex] = "module.exports['#{label}'] = #{exportType} #{label}#{trailingContent}"

			when exportType
					@contentLines[lineIndex] = "#{exportType} #{label} = module.exports['#{label}'] = #{trailingContent.replace(/^\s*\=\s*/, '')}"

			when not exportType and not exportMap
				label = trailingContent.match(/^\S+/)[0]
				@contentLines[lineIndex] = "module.exports['#{label}'] = #{trailingContent}"
			# else
			# 	throw new Error "Cannot figure out a way to parse the following ES6 export statement: (line:#{lineIndex+1}) #{entireLine}"



File::replaceImports = (childImports)->
	@imports.forEach (childHash, importIndex)=>
		childFile = @importRefs[childHash]
		childContent = childFile.compiledContent
		targetLine = @lineRefs[importIndex]

		replaceLine = (childPath, entireLine, priorContent, trailingContent, spacing, conditions, defaultMember, members)=>
			if childFile.importedCount > 1
				childContent = "_s$m(#{childFile.contentReference})"
			else
				# ==== Spacing =================================================================================
				if priorContent and priorContent.replace(/\s/g, '') is ''
					spacing = priorContent+spacing
					priorContent = ''

				if spacing and not priorContent
					childContent = helpers.addSpacingToString(childContent, spacing)


				# ==== JS vs. Coffeescript conflicts =================================================================================
				switch
					when @isCoffee and not childFile.isCoffee
						childContent = helpers.formatJsContentForCoffee(childContent)
					

					when childFile.isCoffee and not @isCoffee
						if @options.compileCoffeeChildren
							childContent = coffeeCompiler.compile childContent, 'bare':true
						else
							throw new Error "#{consoleLabels.error} You're attempting to import a Coffee file into a JS file (which will provide a broken file), rerun this import with -C or --compile-coffee-children"


				
				# ==== Minificaiton =================================================================================								
				if @options.uglify
					childContent = uglifier.minify(childContent, {'fromString':true, 'compressor':{'keep_fargs':true, 'unused':false}}).code


			if trailingContent.startsWith(')')
				if priorContent
					spacing += '('
				else
					priorContent = '('
					spacing = ''

			
			if childFile.hasUsefulExports and importData=@importMemberRefs[importIndex]
				@requiresClosure = true
				exportedName = helpers.genUniqueVar()
				varPrefix = if @isCoffee then '' else 'var '
				childContent = "#{varPrefix}#{exportedName} = #{childContent};\n"

				if importData.default
					childContent += "#{varPrefix}#{importData.default} = #{exportedName}['*default*'];\n"
				
				for key,alias of importData.members
					if key is '!*!'
						childContent += "#{varPrefix}#{alias} = #{exportedName};\n"
					else
						childContent += "#{varPrefix}#{alias} = #{exportedName}['#{key}'];\n"


			if priorContent and childContent
				childContent = priorContent + spacing + childContent

			return childContent+trailingContent
		
		if regEx.import.test(@contentLines[targetLine])
			@contentLines[targetLine] = @contentLines[targetLine].replace regEx.import, (entireLine, priorContent, spacing, conditions, defaultMember, members, childPath, trailingContent)->
				replaceLine(childPath, entireLine, priorContent, trailingContent, spacing, conditions, defaultMember, members)
		else
			@contentLines[targetLine] = @contentLines[targetLine].replace regEx.commonJS.import, (entireLine, priorContent, bracketOrSpace, childPath, trailingContent)->
				replaceLine(childPath, entireLine, priorContent, trailingContent, '')

	return




File::replaceBadImports = ()->
	for badImport,index in @badImports
		targetLine = @lineRefs['bad_'+index]

		if @options.preserve
			@contentLines[targetLine] = helpers.commentOut(@contentLines[targetLine], @isCoffee)
		else
			@contentLines.splice(targetLine, 1)




File::prependDuplicateRefs = (content)->
	duplicates = (file for hash,file of @importRefs when file.importedCount > 1)
	return content if not duplicates.length

	Promise
		.all duplicates.map (file)-> file.compile()
		.then ()=>
			assignments = []
			
			for file in duplicates
				value = if @isCoffee and not file.isCoffee
							helpers.formatJsContentForCoffee(file.compiledContent)
						else
							file.compiledContent

				assignments.push "m[#{file.contentReference}] = #{value}"

			loader = helpers.wrapInLoaderClosure(assignments, '\t', @isCoffee)
			result = "#{loader}\n#{content}"
			result = if @options.preventGlobalLeaks then helpers.wrapInClosure(result, @isCoffee) else result
			return result





File::compile = (importerStack=[])-> if @compilePromise then @compilePromise else
	return (@compiledContent=@content) if not @options.recursive and not @isMain
	### istanbul ignore next ###
	importerStack.push(@) unless importerStack.includes(@)

	childImportsPromise = Promise.delay().then ()=>
		Promise.all @imports.map (hash)=>
			childFile = @importRefs[hash]
			childFile.compile(importerStack) unless importerStack.includes(childFile)

		
	@compilePromise = childImportsPromise
		.then (childImports)=>
			@replaceImports(childImports)
			@replaceBadImports(childImports)
			return @contentLines.join '\n'

		.then (compiledResult)=>
			# console.log(@requiresReturnedClosure, @requiresClosure) if @requiresClosure and not @isMain
			switch
				when @isMain
					return @prependDuplicateRefs(compiledResult)
				
				when @hasExports
					return helpers.wrapInExportsClosure(compiledResult, @isCoffee, @importedCount>1)
				
				when @requiresReturnedClosure or @importedCount>1
					if @isCoffee
						return helpers.wrapInClosure(compiledResult, @isCoffee, @importedCount>1)
					else
						modifiedContent = helpers.modToReturnLastStatement(compiledResult||='{}', @filePathSimple)
						if modifiedContent is 'ExpressionStatement'
							return compiledResult unless @importedCount>1
							modifiedContent = "return #{compiledResult}"
						
						return helpers.wrapInClosure(modifiedContent, false, @importedCount>1)
					### istanbul ignore next ###
				
				when @requiresClosure
					return helpers.wrapInClosure(compiledResult, @isCoffee, @importedCount>1)

				else compiledResult
		
		.then (compiledResult)=>
			if @options.toES5 and not @isCoffee and @isMain
				helpers.transpileES6toES5(compiledResult)
			else
				compiledResult
		
		.then (result)=> @compiledContent = result or '{}'





File.instanceCache = {}
module.exports = File
