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
globalDec = 'typeof global !== "undefined" ? global : typeof self !== "undefined" ? self : typeof window !== "undefined" ? window : {}'
coreModulesUnsupported = ['child_process', 'cluster', 'dgram', 'dns', 'fs', 'module', 'net', 'readline', 'repl', 'tls']
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
			membersString = membersString
				.replace /^\{\s*/, ''
				.replace /\s*\}$/, ''

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


	genUniqueVar: ()->
		"_sim_#{Math.floor((1+Math.random()) * 100000).toString(16)}"


	addSpacingToString: (string, spacing, offset)->
		lines = string.split '\n'
		linesToSpace = if offset then lines.slice(offset) else lines
		spacedOutLines = linesToSpace.map (line)-> spacing+line
		offsettedOutLines = if offset then lines.slice(0, offset) else []
		
		offsettedOutLines.concat(spacedOutLines).join('\n')



	escapeBackticks: (content)->
		content
			.replace REGEX.preEscapedBackTicks, '`'
			.replace REGEX.backTicks, '\\`'



	formatJsContentForCoffee: (jsContent)->
		jsContent
			.replace REGEX.escapedNewLine, ''
			.replace REGEX.fileContent, (entire, spacing, content)-> # Wraps standard javascript code with backtics so coffee script could be properly compiled.
				"#{spacing}`#{helpers.escapeBackticks(content)}`"


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


	modToReturnLastStatement: (content, filePath)-> switch
		when not filePath.endsWith('js')
			return "return #{content}" if filePath.endsWith('json')
			return false

		when err = require('syntax-error')(content, filePath)
			console.error(LABELS.warn, err)
			return content

		else
			AST = acorn.parse(content, {allowReserved:true, allowReturnOutsideFunction:true})
			lastStatement = AST.body[AST.body.length-1]

			switch
				when AST.body.length is 1 and lastStatement.type is 'ExpressionStatement' and lastStatement.start is 0
					return 'ExpressionStatement'
				
				else switch lastStatement.type
					when 'ReturnStatement'
						return content
					
					when 'ExpressionStatement'
						AST.body[AST.body.length-1] = escodegen.ReturnStatement(lastStatement.expression)
						return escodegen.generate(AST)
					
					when 'VariableDeclaration'
						lastDeclarationID = lastStatement.declarations.slice(-1)[0].id
						AST.body.push escodegen.ReturnStatement(lastDeclarationID)
						return escodegen.generate(AST)

					else return content



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


	isCoreModule: (moduleName)->
		coreModulesUnsupported.includes(moduleName)

	helpers.newParsedToken = ()->
		id: null
		range: null
		tokenRange: null
		source: null
		target: null
		extract: null
		conditions: null
		defaultMember: null
		members: null


	walkTokens: (tokens, valueToStopAt, cb)->
		results = []
		api =
			index: 0
			next: ()-> tokens[++@index] or {}

		for token,index in tokens when token.value is valueToStopAt
			result = cb.call(api, token, api.index=index)
			if result
				result.tokenRange = [index, api.index]
				results.push(result)

		return results








dirListingCache = {}
module.exports = helpers