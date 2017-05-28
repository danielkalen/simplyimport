Promise = require 'bluebird'
resolveModule = Promise.promisify require('browser-resolve')
fs = Promise.promisifyAll require 'fs-extra'
Path = require 'path'
chalk = require 'chalk'
coffeeAST = require('decaffeinate-parser').parse
# acorn = require 'acorn'
escodegen = require 'escodegen'
findPkgJson = require 'read-pkg-up'
REGEX = require './constants/regex'
LABELS = require './constants/consoleLabels'
EXTENSIONS = require './constants/extensions'
EMPTY_FILE_END = Path.join('node_modules','browser-resolve','empty.js')
EMPTY_FILE = Path.resolve(__dirname,'..',EMPTY_FILE_END)
coreModuleShims = require('./constants/coreShims')(EMPTY_FILE)



escodegen.ReturnStatement = (argument)-> {type:'ReturnStatement', argument}

moduleResolveError = (err)-> err.message.startsWith('Cannot find module')



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

	testForComments: (line, isCoffee)->
		hasSingleLineComment = line.includes(if isCoffee then '#' else '//')
		hasDocBlockComment = /^(?:\s+\*|\*)/.test(line)

		return hasSingleLineComment or hasDocBlockComment

	
	testForOuterString: (line)->
		insideQuotes = line.match(REGEX.stringContents)
		
		if insideQuotes
			importSyntax = do ()->
				word = if REGEX.import.test(line) then 'import' else 'require'
				new RegExp("\\b#{word}\\b")
			
			for quote in insideQuotes
				return true if importSyntax.test(quote)
		
		return false


	testConditions: (allowedConditions, conditionsString)->
		return true if allowedConditions.length is 1 and allowedConditions[0] is '*'
		conditions = conditionsString.split(/,\s?/).filter (nonEmpty)-> nonEmpty

		for condition in conditions
			return false if not allowedConditions.includes(condition)

		return true


	testIfIsExportMap: (string)->
		if objContents=string.match(/^\{(.+?)\};?$/)?[1]
			return not objContents.includes(':')

		return false


	testIfCoffeeIsExpression: (string)->
		try
			AST = coffeeAST(string).body
			return AST.statements.length is 1
		catch
			return string.split(REGEX.newLine).length is 1


	testIfIsIgnored: (ignoreRanges, targetIndex)->
		for range in ignoreRanges
			return true if range.start < targetIndex < range.end

		return false


	testIfIsLocalModule: (moduleName)->
		return moduleName.startsWith('/') or moduleName.includes('./')



	commentOut: (line, isCoffee)->
		comment = if isCoffee then '#' else '//'
		line.replace /import/, (entire)-> "#{comment} #{entire}"



	getDirListing: (dirPath, fromCache)->
		if dirListingCache[dirPath]? and fromCache
			return Promise.resolve dirListingCache[dirPath]
		else
			fs.readdirAsync(dirPath).then (listing)->
				return dirListingCache[dirPath] = listing


	parseMembersString: (membersString)->
		if not membersString
			return {}
		else
			output = {}
			membersString = membersString.removeAll(REGEX.curlyBrackets).trim()

			if membersString.startsWith('*')
				output['!*!'] = membersString.split(/\s+as\s+/)[1]

			else #if membersString.startsWith('{')
				members = membersString.split(/,\s*/)
				members.forEach (memberSignature)->
					member = memberSignature.split(/\s+as\s+/)
					output[member[0]] = member[1] or member[0] # alias

			return output


	normalizeExportMap: (mappingString)->
		output = mappingString
			.replace /^\{\s*/, ''
			.replace /\s*\}$/, ''
			.split /,\s*/
			.map (memberSignature)->
				member = memberSignature.split(/\s+as\s+/)
				"'#{member[1] or member[0]}':#{member[0]}" # alias
			.join ', '

		return "{#{output}}"


	wrapInClosure: (content, isCoffee, asFunc, debugRef)->
		if isCoffee
			debugRef = " ##{debugRef}" if debugRef
			arrow = if REGEX.thisKeyword.test(content) then '=>' else '->'
			fnSignatureStart = if asFunc then "()#{arrow}" else "do ()#{arrow}"
			fnSignatureEnd = ''
		else
			debugRef = " //#{debugRef}" if debugRef
			fnSignatureStart = if asFunc then 'function(){' else '(function(){'
			fnSignatureEnd = if asFunc then '}' else '}).call(this)'

		"#{fnSignatureStart}#{debugRef}\n\
			#{@addSpacingToString content, '\t'}\n\
		#{fnSignatureEnd}
		"


	wrapInGlobalsClosure: (content, file)->
		requiredGlobals = file.requiredGlobals.filter (item)-> item isnt 'process'
		return content if not requiredGlobals.length
		
		values = requiredGlobals.map (name)-> switch name
			when '__dirname' then "'#{file.contextRel}'"
			when '__filename' then "'#{file.filePathRel}'"
			when 'global' then (if file.isCoffee then "`#{globalDec}`" else globalDec)
		
		if file.isCoffee
			args = requiredGlobals.map (name, index)-> "#{name}=#{values[index]}"
			argValues = args.join(',')
			"do (#{argValues})=>\n\
				#{@addSpacingToString content, '\t'}\n\
			"
		else
			args = requiredGlobals.join(',')
			values = values.join(',')
			";(function(#{args}){\n\
				#{@addSpacingToString content, '\t'}\n\
			}).call(this, #{values})
			"



	wrapInExportsClosure: (content, isCoffee, asFunc, debugRef)->
		if isCoffee
			debugRef = " ##{debugRef}" if debugRef
			fnSignature = if asFunc then '(exports)->' else "do (exports={})=>"
			"#{fnSignature}#{debugRef}\n\
				\t`var module = {exports:exports}`\n\
				#{@addSpacingToString content, '\t'}\n\
				\treturn module.exports
			"
		else
			debugRef = " //#{debugRef}" if debugRef
			fnSignatureStart = if asFunc then 'function(exports){' else '(function(exports){'
			fnSignatureEnd = if asFunc then '}' else '}).call(this, {})'
			"#{fnSignatureStart}#{debugRef}\n\
				\tvar module = {exports:exports};\n\
				#{@addSpacingToString content, '\t'}\n\
				\treturn module.exports;\n\
			#{fnSignatureEnd}
			"


	wrapInLoaderClosure: (assignments, spacing, isCoffee)->
		if isCoffee
			assignments = @addSpacingToString assignments.join('\n'), spacing
			loader = "\
				_s$m=(m,c,l,_s$m)->\n\
					#{spacing}_s$m=(r)->\
						if l[r] then c[r] else `(l[r]=1,c[r]={},c[r]=m[r](c[r]))`\n\
					#{assignments}\n\
					#{spacing}_s$m\n\
				_s$m=_s$m({},{},{});"
		else
			assignments = assignments.join('\n')
			loader = "\
				var _s$m=function(m,c,l,_s$m){\
					_s$m=function(r){\
						return l[r] ? c[r]\
									: (l[r]=1,c[r]={},c[r]=m[r](c[r]));\
					};\n\
					#{assignments}\n\
					return _s$m;\
				};\ _s$m=_s$m({},{},{});
			"


	resolveModulePath: (moduleName, basedir, basefile, pkgFile)-> Promise.resolve().then ()->
		fullPath = Path.resolve(basedir, moduleName)
		output = 'file':fullPath
		
		if helpers.testIfIsLocalModule(moduleName)
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

				.catch moduleResolveError, (err)-> #return output
					helpers.resolveModulePath("./#{moduleName}", basedir, basefile, pkgFile)


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

					if helpers.testIfIsLocalModule(key)
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


	newImportStatement: ()->
		id: null
		range: null
		tokenRange: null
		source: null
		target: null
		extract: null
		conditions: null
		defaultMember: null
		members: null
		alias: null

	newExportStatement: ()->
		range: null
		tokenRange: null
		source: null
		target: null
		members: null
		keyword: null
		identifier: null


	walkTokens: (tokens, valueToStopAt, cb)->
		walker = new TokenWalker(tokens, cb)
		walker.invoke(token, i) for token,i in tokens when token.value is valueToStopAt
		return walker.finish()


	collectRequires: (tokens)->
		@walkTokens tokens, 'require', ()->
			@next()
			@next() if @current.type is 'Punctuator'
			return if @current.type isnt 'String'
			output = helpers.newImportStatement()
			output.target = @current.value.removeAll(REGEX.quotes).trim()

			return output if @next().value isnt ','
			return output if @next().value isnt 'string'
			output.conditions = @current.value.removeAll(REGEX.squareBrackets).trim().split(REGEX.commaSeparated)

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


	collectImports: (tokens)->
		@walkTokens tokens, 'import', ()->
			output = helpers.newImportStatement()

			while @next().type isnt 'String' then switch
				when @current.type is 'Punctuator'
					@handleMemebers(output)

				when @current.type is 'Identifier' and @current.value isnt 'from'
					@handleDefault(output)

			if @current.type is 'String'
				output.target = @current.value.removeAll(REGEX.quotes).trim()

			return output


	collectExports: (tokens)->
		@walkTokens tokens, 'export', ()->
			output = helpers.newImportStatement()
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
						isDefault = true
						output.members = {}
						@next()
					
					if @current.type is 'Keyword'
						output.keyword = @current.value
						@next()

					if @current.type is 'Identifier'
						output.identifier = @current.value
						output.members.default = @current.value if isDefault
						
				else throw @newError()

			return output



class TokenWalker
	constructor: (@tokens, @callback)->
		@index = 0
		@current = null
		@results = []

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
			result.tokenRange = [index, @index]
			@results.push(result)
		
		return


	finish: ()->
		delete @current
		delete @results
		delete @callback
		return @results


	newError: ()->
		err = new Error "unexpected #{@current.type} '#{@current.value}' at offset #{@current.range[0]}"
		err.name = 'TokenError'
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
				@storeMembers(output.members ?= {})

			when '['
				output.conditions = @nextUntil(']', 'from', 'String').map('value').exclude(',')
	

	handleDefault: (output)->
		output.members.default = @current.value





dirListingCache = {}
module.exports = helpers