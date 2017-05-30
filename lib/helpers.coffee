Promise = require 'bluebird'
promiseBreak = require 'promise-break'
resolveModule = Promise.promisify require('browser-resolve')
fs = require 'fs-jetpack'
Path = require 'path'
chalk = require 'chalk'
escodegen = require 'escodegen'
findPkgJson = require 'read-pkg-up'
REGEX = require './constants/regex'
LABELS = require './constants/consoleLabels'
EXTENSIONS = require './constants/extensions'
EMPTY_FILE_END = Path.join('node_modules','browser-resolve','empty.js')
EMPTY_FILE = Path.resolve(__dirname,'..',EMPTY_FILE_END)
coreModuleShims = require('./constants/coreShims')(EMPTY_FILE)




helpers = 
	getNormalizedDirname: (targetPath)->
		Path.normalize( Path.dirname( Path.resolve(targetPath) ) )

	simplifyPath: (targetPath)->
		targetPath.replace process.cwd()+'/', ''

	changeExtension: (filePath, extension)->
		filePath = filePath.replace(/\.\w+?$/,'')
		return "#{filePath}.#{extension}"

	isMixedExtStatement: (statement)->
		source = statement.source.fileExt
		target = statement.target.fileExt
		sourceRelated = helpers.relatedExtensions(source)
		targetRelated = helpers.relatedExtensions(target)
		return  source isnt target and
				(
					sourceRelated isnt targetRelated or
					target is 'js' # and source is a transpiled type (e.g. coffeescript, typescript)
				) and
				sourceRelated isnt EXTENSIONS.data

	relatedExtensions: (ext)-> switch
		when EXTENSIONS.js.includes(ext) then EXTENSIONS.js
		when EXTENSIONS.css.includes(ext) then EXTENSIONS.css
		when EXTENSIONS.html.includes(ext) then EXTENSIONS.html
		when EXTENSIONS.data.includes(ext) then EXTENSIONS.data
		else EXTENSIONS.none


	isIgnored: (ignoreRanges, targetIndex)->
		for range in ignoreRanges
			return true if range.start < targetIndex < range.end

		return false


	isLocalModule: (moduleName)->
		return moduleName.startsWith('/') or moduleName.includes('./')


	getDirListing: (dirPath, fromCache)->
		if fromCache and helpers.getDirListing.cache[dirPath]?
			return helpers.getDirListing.cache[dirPath]
		else
			Promise.resolve(fs.listAsync(dirPath))
				.tap (listing)-> helpers.getDirListing.cache[dirPath] = listing


	resolveFilePath: (input, entryContext, useDirCache)->
		Promise.resolve()
			.then ()->
				extname = Path.extname(input).slice(1).toLowerCase()
				if extname and EXTENSIONS.all.includes(extname)
					promiseBreak(input)
				else
					Path.parse(input)
			
			.then (params)->
				helpers.getDirListing(params.dir, useDirCache).then (list)-> [params, list]
			
			.then ([params, dirListing])->
				inputPathMatches = dirListing.filter (targetPath)-> targetPath.includes(params.base)

				if not inputPathMatches.length
					return promiseBreak(input)
				else
					exactMatch = inputPathMatches.find(params.base)
					fileMatch = inputPathMatches.find (targetPath)->
						fileNameSplit = targetPath.replace(params.base, '').split('.')
						return !fileNameSplit[0] and fileNameSplit.length is 2 # Ensures the path is not a dir and is exactly the inputPath+extname

					if fileMatch
						promiseBreak Path.join(params.dir, fileMatch)
					else #if exactMatch
						return params
			
			.then (params)->
				resolvedPath = Path.join(params.dir, params.base)
				fs.inspectAsync(resolvedPath).then (stats)->
					if stats.type isnt 'dir'
						promiseBreak(resolvedPath)
					else
						return params

			.then (params)->
				helpers.getDirListing(Path.join(params.dir, params.base), useDirCache).then (list)-> [params, list]

			.then ([params, dirListing])->
				indexFile = dirListing.find (file)-> file.includes('index')
				return Path.join(params.dir, params.base, if indexFile then indexFile else 'index.js')

			.catch promiseBreak.end
			.then (filePath)->
				context = helpers.getNormalizedDirname(filePath)
				contextRel = context.replace(entryContext+'/', '')
				filePathSimple = helpers.simplifyPath(filePath)
				filePathRel = filePath.replace(entryContext+'/', '')
				fileExt = Path.extname(filePath).toLowerCase().slice(1)
				fileExt = 'yml' if fileExt is 'yaml'
				fileBase = Path.basename(filePath)
				suppliedPath = input
				return {filePath, filePathSimple, filePathRel, fileBase, fileExt, context, contextRel, suppliedPath}




	resolveModulePath: (moduleName, basedir, basefile, pkgFile)-> Promise.resolve().then ()->
		fullPath = Path.resolve(basedir, moduleName)
		output = 'file':fullPath
		
		if helpers.isLocalModule(moduleName)
			if pkgFile and typeof pkgFile.browser is 'object'
				replacedPath = pkgFile.browser[fullPath]
				replacedPath ?= pkgFile.browser[fullPath+'.js']
				replacedPath ?= pkgFile.browser[fullPath+'.ts']
				replacedPath ?= pkgFile.browser[fullPath+'.coffee']
				
				if replacedPath?
					if typeof replacedPath isnt 'string'
						output.file = EMPTY_FILE
						output.isEmpty = true
					else
						output.file = replacedPath

			output.pkg = pkgFile
			return output

		else		
			resolveModule(moduleName, {basedir, filename:basefile, modules:coreModuleShims})
				.then (moduleFullPath)->
					findPkgJson(normalize:false, cwd:moduleFullPath).then (result)->
						output.file = moduleFullPath
						output.pkg = result.pkg
						
						if moduleFullPath.endsWith EMPTY_FILE_END
							output.isEmpty = true
							delete output.pkg
						else
							helpers.resolvePackagePaths(result.pkg, result.path)
						
						return output

				.catch(
					(err)-> err.message.startsWith('Cannot find module')
					()-> helpers.resolveModulePath("./#{moduleName}", basedir, basefile, pkgFile)
				)


	resolvePackagePaths: (pkgFile, pkgPath)->
		pkgFile.srcPath = pkgPath
		pkgFile.dirPath = Path.dirname(pkgPath)
		pkgFile.main = 'index.js' if not pkgFile.main
		pkgFile.main = Path.resolve(pkgFile.dirPath, pkgFile.main)
		
		if pkgFile.browser then switch typeof pkgFile.browser
			when 'string'
				pkgFile.browser = pkgFile.main = Path.resolve(pkgFile.dirPath, pkgFile.browser)

			when 'object'
				browserField = pkgFile.browser
				
				for key,value of browserField
					if typeof value is 'string'
						browserField[key] = value = Path.resolve(pkgFile.dirPath, value)

					if helpers.isLocalModule(key)
						newKey = Path.resolve(pkgFile.dirPath, key)
						browserField[newKey] = value
						delete browserField[key]

		return


	resolveTransformer: (transformer, basedir)-> Promise.resolve().then ()-> switch
		when typeof transformer is 'function'
			{'fn':transformer, 'opts':{}}

		when typeof transformer is 'object' and helpers.isValidTransformerArray(transformer)
			{'fn':helpers.safeRequire(transformer[0], basedir), 'opts':transformer[1], 'name':transformer[0]}

		when typeof transformer is 'string'
			{'fn':helpers.safeRequire(transformer, basedir), 'opts':{}, 'name':transformer}

		else throw new Error "Invalid transformer provided (must be a function or a string representing the file/module path of the transform function). Received:'#{String(transformer)}'"


	safeRequire: (targetPath, basedir)->
		if basedir
			require(Path.join(basedir, targetPath))
		
		else if targetPath.includes('.') or targetPath.includes('/')
			require(Path.resolve(targetPath))
		
		else
			require(targetPath)


	isValidTransformerArray: (transformer)->
		Array.isArray(transformer) and
		transformer.length is 2 and
		typeof transformer[0] is 'string' and
		typeof transformer[1] is 'object' and
		transformer[1] not instanceof Array


	randomVar: ()->
		"_s#{Math.floor((1+Math.random()) * 100000).toString(16)}"


	prepareMultilineReplacement: (sourceContent, targetContent, lines, range)->
		if targetContent.lines().length <= 1
			return targetContent
		else
			loc = lines.locationForIndex(range[0])
			contentLine = sourceContent.slice(range[0] - loc.column, range[1])
			priorWhitespace = contentLine.match(REGEX.initialWhitespace)?[0] or ''
			hasPriorLetters = contentLine.length - priorWhitespace.length > range[1]-range[0]

			if not priorWhitespace
				return targetContent
			else
				targetContent
					.split '\n'
					.map (line, index)-> if index is 0 and hasPriorLetters then line else "#{priorWhitespace}#{line}"
					.join '\n'


	accumulateRangeOffset: (pos, ranges)->
		offset = 0
		for range in ranges
			break if range[0] <= pos
			offset += range[2]

		return offset


	newImportStatement: ()->
		# id: null
		type: ''
		range: []
		tokenRange: []
		source: null
		target: null
		extract: null
		conditions: null
		members: null
		alias: null

	newExportStatement: ()->
		# id: null
		range: []
		tokenRange: []
		source: null
		target: null
		default: null
		members: null
		keyword: null
		identifier: null


	walkTokens: (tokens, lines, valueToStopAt, cb)->
		walker = new TokenWalker(tokens, lines, cb)
		
		for token,i in tokens when (if valueToStopAt? then token.value is valueToStopAt else true)
			walker.invoke(token, i)
		
		return walker.finish()


	collectRequires: (tokens, lines)->
		@walkTokens tokens, lines, 'require', ()->
			@next()
			@next() if @current.type is 'Punctuator'
			return if @current.type isnt 'String'
			output = helpers.newImportStatement()
			output.target = @current.value.removeAll(REGEX.quotes).trim()

			return output if @next().value isnt ','
			return output if @next().value isnt 'string'
			output.members ?= {}
			output.members.default = @current.value.removeAll(REGEX.quotes).trim()

			return output if @next().value isnt ','
			return output if @next().value isnt 'string'
			output.members ?= {}
			members = @current.value.removeAll(REGEX.quotes).trim()

			if members.startsWith '*'
				split = members.split(REGEX.es6membersAlias)
				output.alias = split[1]
			else
				members.split(/,\s*/).forEach (memberSignature)->
					split = memberSignature.split(REGEX.es6membersAlias)
					output.members[split[0]] = split[1] or split[0]

			return output


	collectImports: (tokens, lines, keyword='import')->
		@walkTokens tokens, lines, keyword, ()->
			output = helpers.newImportStatement()
			if @next().type is 'String'
				@prev()
			else
				throw @newError()

			while @next().type isnt 'String' then switch
				when @current.type is 'Punctuator'
					@handleMemebers(output)

				when @current.type is 'Identifier' and @current.value isnt 'from'
					@handleDefault(output)

			if @current.type is 'String'
				output.target = @current.value.removeAll(REGEX.quotes).trim()

			return output

	collectInlines: (tokens, lines)->
		helpers.collectImports(tokens, lines, 'importInline')

	collectExports: (tokens, lines)->
		@walkTokens tokens, lines, 'export', ()->
			output = helpers.newExportStatement()
			@next()

			switch @current.type
				when 'Punctuator'
					@handleMemebers(output)
					@next() if @current.value is 'as'
					throw @newError() if @current.value isnt 'from' or @next().type isnt 'String'
					
					output.members = Object.invert(output.members) if output.members
					output.target = @current.value.removeAll(REGEX.quotes).trim()
				
				when 'Keyword'
					if @current.value is 'default'
						output.default = true
						@next()
					
					if @current.type is 'Keyword'
						output.keyword = @current.value
						@next()

					if @current.type is 'Identifier'
						output.identifier = @current.value
					else if @current.value isnt '='
						@prev()
						
				else throw @newError()

			return output



class TokenWalker
	constructor: (@tokens, @lines, @callback)->
		@index = 0
		@current = null
		@results = []

	prev: ()->
		@current = @tokens[--@index]

	next: ()->
		@current = @tokens[++@index] or {}

	nextUntil: (stopAt, invalidValue, invalidType)->
		pieces = []
		while @next().value isnt stopAt
			pieces.push(@current)
			
			if @current.value is invalidValue or @current.type is invalidType
				throw @newError()

		return pieces


	invoke: (@current, index)->
		@index = index
		result = @callback(@current, @index)


		if result
			result.tokenRange[0] = index
			result.tokenRange[1] = @index
			@results.push(result)
		
		return


	finish: ()->
		results = @results
		delete @current
		delete @results
		delete @callback
		return results


	newError: ()->
		loc = @lines.locationForIndex(@current.range[0])
		err = new Error "unexpected #{@current.type} '#{@current.value}' at line #{loc.line+1}:#{loc.column}"
		err.name = 'TokenError'
		err.stack = err.stack.lines().slice(1).join('\n')
		return err


	storeMembers: (store)->
		items = @nextUntil '}', 'from', 'String'

		items.reduce (store, token, index)->
			if token.type is 'Identifier' and token.value isnt 'as'
				if items[index-1].value is 'as'
					store[items[index-2].value] = token.value
				else
					store[token.value] = token.value
			return store
		
		, store


	handleMemebers: (output)->
		switch @current.value
			when '*'
				if @next().value is 'as'
					output.alias = @current.value

			when '{'
				@storeMembers(output.members ?= Object.create(null))

			when '['
				output.conditions = @nextUntil(']', 'from', 'String').map('value').exclude(',')
	

	handleDefault: (output)->
		console.log @tokens
		# output.members ?= {}
		output.members.default = @current.value





helpers.getDirListing.cache = {}
module.exports = helpers