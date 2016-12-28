Promise = require 'bluebird'
fs = Promise.promisifyAll require 'fs'
replaceAsync = require 'string-replace-async'
md5 = require 'md5'
PATH = require 'path'
chalk = require 'chalk'
Streamify = require 'streamify-string'
Browserify = require 'browserify'
Browserify::bundleAsync = Promise.promisify(Browserify::bundle, ctx:Browserify::)
coffeeCompiler = require 'coffee-script'
uglifier = require 'uglify-js'
regEx = require './regex'
helpers = require './helpers'
consoleLabels = require './consoleLabels'



###*
 * The object created for each file path the program needs to open/import/read.
 * @param {String} input               	File's path or file's contents
 * @param {Object} state	          	(optional) initial state map to indicate if 'isStream', 'isCoffee', and 'context'
 * @param {Object} importHistory	 	(optional) the import history collected so far since the main faile import
###
module.exports = File = (input, @options, @importRefs, {@isMain, @isCoffee, @context}={})->
	@input = input
	@imports = []
	@badImports = []
	@lineRefs = {}

	return @



File::process = ()->
	Promise.bind(@)
		.then(@getFilePath)
		.then(@resolveContext)
		.then(@checkIfIsCoffee)
		.then(@getContents)
		


File::getContents = ()->
	if @isMain
		@contentLines = @input.split '\n'
		return @content = @input
	else
		fs.readFileAsync(@filePath, encoding:'utf8')
			.then (content)=>
				@content = content
				@hash = md5(content)
				@contentLines = content.split '\n'
				return content

			.catch (err)=>
				if err?.code is 'ENOENT'
					console.error "#{consoleLabels.error} File doesn't exist #{chalk.dim(helpers.simplifyPath @filePath)}"
					Promise.reject(err)



File::getFilePath = ()->
	if @isMain
		return @context
	
	else if PATH.extname(@input)
		return @filePath = @input
	
	else
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




File::resolveContext = ()->
	if @isMain
		@context
	else
		@context = helpers.getNormalizedDirname(@filePath)


File::checkIfIsCoffee = ()->
	@isCoffee = if @isMain then @isCoffee else PATH.extname(@filePath).toLowerCase().slice(1) is 'coffee'


File::addLineRef = (entireLine, targetRef)->
	entireLine = entireLine.slice(0,-1) if entireLine.slice(-1)[0] is '\n'
	@lineRefs[targetRef] ?= []
	@lineRefs[targetRef].push @contentLines.indexOf(entireLine)



File::collectImports = ()-> @collectedImports or @collectedImports =
	replaceAsync @content, regEx.import, (entireLine, priorContent, spacing, conditions='', childPath)=>
		childPath = childPath
			.replace /['"]/g, '' # Remove quotes form pathname
			.replace /\s+$/, '' # Remove whitespace from the end of the string
		childPath = PATH.resolve(@context, childPath)

		if helpers.testForComments(entireLine, @isCoffee)
			Promise.resolve()
		
		else if not helpers.testConditions(@options.conditions, conditions)
			@addLineRef(entireLine, childPath)
			@badImports.push(childPath)
			Promise.resolve()
		
		else
			childFile = new File childPath, @options, @importRefs
			childFile.process().then ()=>
				@importRefs.duplicates[childFile.hash] = helpers.genUniqueVar() if @importRefs[childFile.hash] and not @importRefs.duplicates[childFile.hash]
				@importRefs[childFile.hash] = childFile
				@imports.push(childFile.hash)
				@addLineRef(entireLine, childFile.hash)
				Promise.resolve()


	.then ()=>
		if @options.recursive
			Promise.all(@importRefs[childFileHash].collectImports() for childFileHash in @imports)




File::compile = ()->
	return (@compiledContent=@content) if not @options.recursive and not @isMain

	Promise
		.all(@importRefs[childFileHash].compile() for childFileHash in @imports)
		.then (childImports)=>
			@replaceImports(childImports)
			@replaceBadImports(childImports)
			return @contentLines.join '\n'
			


		.then (compiledResult)=>
			if not @isMain
				return @compiledContent = compiledResult
			else
				compiledResult = @prependDuplicateRefs(compiledResult)

				if regEx.commonJS.import.test(compiledResult) or regEx.commonJS.export.test(compiledResult)
					compiledResult = if @isCoffee then coffeeCompiler.compile(compiledResult, 'bare':true) else compiledResult
					
					Browserify(Streamify(compiledResult), {basedir:@context}).bundleAsync().then (contentBuffer)=>
						compiledResult = contentBuffer.toString()
						compiledResult = helpers.formatJsContentForCoffee(compiledResult) if @isCoffee
						return @compiledContent = compiledResult
				else
					return @compiledContent = compiledResult





File::replaceImports = (childImports)->
	for childHash,index in @imports
		childFile = @importRefs[childHash]
		childContent = childImports[index]

		for targetLine in @lineRefs[childHash]
			@contentLines[targetLine] = @contentLines[targetLine].replace regEx.import, (entireLine, priorContent, spacing, conditions, childPath)=>
				if @importRefs.duplicates[childHash]
					childContent = @importRefs.duplicates[childHash]
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


				if priorContent and childContent
					childContent = priorContent + spacing + childContent

				return childContent	




File::replaceBadImports = ()->
	for badImport in @badImports
		for targetLine in @lineRefs[badImport]
			if @options.preserve
				@contentLines[targetLine] = helpers.commentOut(@contentLines[targetLine], @isCoffee, true)
			else
				@contentLines.splice(targetLine, 1)



File::prependDuplicateRefs = (content)->
	if Object.keys(@importRefs.duplicates).length
		assignments = []
		
		for importHash,varName of @importRefs.duplicates
			childFile = @importRefs[importHash]
			declaration = if not @isCoffee then "var #{varName}" else varName
			
			if @isCoffee
				value = "do ()=> \n#{helpers.addSpacingToString childFile.content, '\t'}"
			else
				value = "(function(){"
				value += if childFile.contentLines.length is 1 and not childFile.compiledContent.startsWith('var') then "return #{childFile.compiledContent}" else childFile.compiledContent
				value += "}).call(this)"
			
			assignments.push "#{declaration} = #{value}"

		assignments = assignments.reverse().join('\n')
		if @isCoffee
			content = "
				do ()=>
					#{helpers.addSpacingToString assignments}\n
					#{helpers.addSpacingToString content}
			"
		else
			content = "
				(function(){\n
					#{assignments}\n
					#{content}\n
				}).call(this);
			"

	return content






