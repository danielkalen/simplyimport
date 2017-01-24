Promise = require 'bluebird'
resolveModule = Promise.promisify require('browser-resolve')
fs = Promise.promisifyAll require 'fs-extra'
path = require 'path'
chalk = require 'chalk'
coffeeAST = require('decaffeinate-parser').parse
acorn = require 'acorn'
escodegen = require 'escodegen'
regEx = require './regex'
consoleLabels = require './consoleLabels'
stackTraceFilter = require('stack-filter')
stackTraceFilter.filters.push('bluebird')
globalDec = 'typeof global !== "undefined" ? global : typeof self !== "undefined" ? self : typeof window !== "undefined" ? window : {}'
coreModulesUnsupported = ['child_process', 'cluster', 'dgram', 'dns', 'fs', 'module', 'net', 'readline', 'repl', 'tls']
basedir = 'basedir':path.resolve(__dirname,'..')
coreModuleShims = 
	'': path.resolve(__dirname,'..','node_modules','')
	'assert':					resolveModule.sync 'assert/', basedir
	'zlib':						resolveModule.sync '@danielkalen/browserify-zlib', basedir
	'buffer':					resolveModule.sync 'buffer/', basedir
	'console':					resolveModule.sync 'console-browserify', basedir
	'constants':				resolveModule.sync 'constants-browserify', basedir
	'crypto':					resolveModule.sync 'crypto-browserify', basedir
	'domain':					resolveModule.sync 'domain-browser', basedir
	'events':					resolveModule.sync 'events/', basedir
	'https':					resolveModule.sync 'https-browserify', basedir
	'os':						resolveModule.sync 'os-browserify', basedir
	'path':						resolveModule.sync 'path-browserify', basedir
	'process':					resolveModule.sync 'process/', basedir
	'punycode':					resolveModule.sync 'punycode/', basedir
	'querystring':				resolveModule.sync 'querystring-es3', basedir
	'http':						resolveModule.sync 'stream-http', basedir
	'string_decoder':			resolveModule.sync 'string_decoder', basedir
	'stream':					resolveModule.sync 'stream-browserify', basedir
	'timers':					resolveModule.sync 'timers-browserify', basedir
	'tty':						resolveModule.sync 'tty-browserify', basedir
	'url':						resolveModule.sync 'url/', basedir
	'util':						resolveModule.sync 'util/', basedir
	'vm':						resolveModule.sync 'vm-browserify', basedir


escodegen.ReturnStatement = (argument)-> {type:'ReturnStatement', argument}




helpers = 
	getNormalizedDirname: (inputPath)->
		path.normalize( path.dirname( path.resolve(inputPath) ) )

	simplifyPath: (inputPath)->
		inputPath.replace process.cwd()+'/', ''

	testForComments: (line, isCoffee)->
		hasSingleLineComment = line.includes(if isCoffee then '#' else '//')
		hasDocBlockComment = /^(?:\s+\*|\*)/.test(line)

		return hasSingleLineComment or hasDocBlockComment

	
	testForOuterString: (line)->
		insideQuotes = line.match(regEx.stringContents)
		
		if insideQuotes
			importSyntax = do ()->
				word = if regEx.import.test(line) then 'import' else 'require'
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
			return false



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
			.replace regEx.preEscapedBackTicks, '`'
			.replace regEx.backTicks, '\\`'



	formatJsContentForCoffee: (jsContent)->
		jsContent
			.replace regEx.escapedNewLine, ''
			.replace regEx.fileContent, (entire, spacing, content)-> # Wraps standard javascript code with backtics so coffee script could be properly compiled.
				"#{spacing}`#{helpers.escapeBackticks(content)}`"


	wrapInClosure: (content, isCoffee, asFunc)->
		if isCoffee
			arrow = if regEx.thisKeyword.test(content) then '=>' else '->'
			fnSignatureStart = if asFunc then "()#{arrow}" else "do ()#{arrow}"
			fnSignatureEnd = ''
		else
			fnSignatureStart = if asFunc then 'function(){' else '(function(){'
			fnSignatureEnd = if asFunc then '}' else '}).call(this)'

		"#{fnSignatureStart}\n\
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
			"(function(#{args}){\n\
				#{@addSpacingToString content, '\t'}\n\
			}).call(this, #{values})
			"



	wrapInExportsClosure: (content, isCoffee, asFunc)->
		if isCoffee
			fnSignature = if asFunc then '(exports)->' else "do (exports={})=>"
			"#{fnSignature}\n\
				\t`var module = {exports:exports}`\n\
				#{@addSpacingToString content, '\t'}\n\
				\treturn module.exports
			"
		else
			fnSignatureStart = if asFunc then 'function(exports){' else '(function(exports){'
			fnSignatureEnd = if asFunc then '}' else '}).call(this, {})'
			"#{fnSignatureStart}\n\
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
			content = "return #{content}" if filePath.endsWith('json')
			return content

		else
			try
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
			
			catch syntaxErr
				OFFSET = 20
				### istanbul ignore next ###
				OFFSET = 0 if content.length < OFFSET*2 or syntaxErr.pos-OFFSET < 0
				MAX_CHARS = 100
				preview = syntaxErr.preview = content.substr syntaxErr.pos-OFFSET, MAX_CHARS
				preview = preview.substr(0,OFFSET) + chalk.red.bold(preview[OFFSET]) + preview.substr(OFFSET+1)
				preview = '\n'+chalk.dim(preview)
				syntaxErr.targetFile = filePath
				syntaxErr.stack = stackTraceFilter.filter(syntaxErr.stack).join('\n')

				console.error(consoleLabels.error, syntaxErr, preview)
				return content




	resolveModulePath: (moduleName, basedir)->
		moduleLoad = if moduleName.startsWith('/') or moduleName.includes('./') then Promise.resolve() else resolveModule(moduleName, {basedir, modules:coreModuleShims})
		moduleLoad
			.then (modulePath)-> Promise.resolve(modulePath)
			.catch (err)-> Promise.resolve()
			.then (modulePath)-> Promise.resolve(modulePath)


	resolveTransformer: (transformer)-> Promise.resolve().then ()->
		if typeof transformer is 'function'
			return 'fn':transformer, 'opts':{}

		else if typeof transformer is 'object' and helpers.isValidTransformerArray(transformer)
			return 'fn':helpers.safeRequire(transformer[0]), 'opts':transformer[1], 'name':transformer[0]

		else if typeof transformer is 'string'
			return 'fn':helpers.safeRequire(transformer), 'opts':{}, 'name':transformer

		else
			Promise.reject("Invalid transformer provided (must be a function or a string representing the file/module path of the transform function). Received:'#{String(transformer)}'")


	safeRequire: (targetPath)->
		if targetPath.includes('.') or targetPath.includes('/')
			require(path.resolve(targetPath))
		else
			require(targetPath)


	isValidTransformerArray: (transformer)->
		Array.isArray(transformer) and
		transformer.length is 2 and
		typeof transformer[0] is 'string' and
		typeof transformer[1] is 'object'


	isCoreModule: (moduleName)->
		coreModulesUnsupported.includes(moduleName)










dirListingCache = {}
module.exports = helpers