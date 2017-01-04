Promise = require 'bluebird'
resolveModule = Promise.promisify require('browser-resolve')
fs = Promise.promisifyAll require 'fs-extra'
path = require 'path'
chalk = require 'chalk'
acorn = require 'acorn'
escodegen = require 'escodegen'
babel = require 'babel-core'
regEx = require './regex'
consoleLabels = require './consoleLabels'
coreModulesUnsupported = ['child_process', 'cluster', 'dgram', 'dns', 'fs', 'module', 'net', 'readline', 'repl', 'tls']
coreModuleShims = 
	'': path.resolve(__dirname,'..','node_modules','')
	'assert':					path.resolve(__dirname,'..','node_modules','assert','assert.js')
	'zlib':						path.resolve(__dirname,'..','node_modules','@danielkalen','browserify-zlib','src','index.js')
	'buffer':					path.resolve(__dirname,'..','node_modules','buffer','index.js')
	'console':					path.resolve(__dirname,'..','node_modules','console-browserify','index.js')
	'constants':				path.resolve(__dirname,'..','node_modules','constants-browserify','constants.json')
	'crypto':					path.resolve(__dirname,'..','node_modules','crypto-browserify','index.js')
	'domain':					path.resolve(__dirname,'..','node_modules','domain-browser','index.js')
	'events':					path.resolve(__dirname,'..','node_modules','events','events.js')
	'https':					path.resolve(__dirname,'..','node_modules','https-browserify','index.js')
	'os':						path.resolve(__dirname,'..','node_modules','os-browserify','browser.js')
	'path':						path.resolve(__dirname,'..','node_modules','path-browserify','index.js')
	'process':					path.resolve(__dirname,'..','node_modules','process','browser.js')
	'punycode':					path.resolve(__dirname,'..','node_modules','punycode','punycode.js')
	'querystring':				path.resolve(__dirname,'..','node_modules','querystring-es3','index.js')
	'http':						path.resolve(__dirname,'..','node_modules','stream-http','index.js')
	'string_decoder':			path.resolve(__dirname,'..','node_modules','string_decoder','index.js')
	'stream':					path.resolve(__dirname,'..','node_modules','stream-browserify','index.js')
	'timers':					path.resolve(__dirname,'..','node_modules','timers-browserify','main.js')
	'tty':						path.resolve(__dirname,'..','node_modules','tty-browserify','index.js')
	'url':						path.resolve(__dirname,'..','node_modules','url','url.js')
	'util':						path.resolve(__dirname,'..','node_modules','util','util.js')
	'vm':						path.resolve(__dirname,'..','node_modules','vm-browserify','index.js')


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
			# importSyntax = if regEx.import.test(line) then /\Wimport\W?/ else /\Wrequire\W?/
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


	addSpacingToString: (string, spacing)->
		string
			.split '\n'
			.map (line)-> spacing+line
			.join '\n'



	escapeBackticks: (content)->
		content
			.replace regEx.preEscapedBackTicks, '`'
			.replace regEx.backTicks, '\\`'



	formatJsContentForCoffee: (jsContent)->
		jsContent
			.replace regEx.escapedNewLine, ''
			.replace regEx.fileContent, (entire, spacing, content)-> # Wraps standard javascript code with backtics so coffee script could be properly compiled.
				"#{spacing}`#{helpers.escapeBackticks(content)}`"



	wrapInExportsClosure: (content, isCoffee)->
		if isCoffee
			"do (exports={})=>\n\
				#{@addSpacingToString 'module = {exports}', '\t'}\n\
				#{@addSpacingToString content, '\t'}\n\
				#{@addSpacingToString 'return exports', '\t'}
			"
		else
			"(function(exports){\n\
				var module = {exports:exports};\n\
				#{content}\n\
			}).call(this, {})
			"


	wrapInClosure: (content, isCoffee, addFakeReturn)->
		if isCoffee
			"do ()=>\n\
				#{@addSpacingToString content, '\t'}\n\
				#{if addFakeReturn then '\treturn' else ''}
				\treturn module.exports
			"
		else
			"(function(){\
				#{content}\
			}).call(this)
				\treturn module.exports;\n\
			"


	modToReturnLastStatement: (content, filePath)->
		try
			AST = acorn.parse(content, {allowReserved:true, allowReturnOutsideFunction:true})
			lastStatement = AST.body[AST.body.length-1]

			switch lastStatement.type
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
			OFFSET = 0 if content.length < OFFSET*2
			MAX_CHARS = 100
			preview = syntaxErr.preview = content.substr syntaxErr.pos-OFFSET, MAX_CHARS
			preview = preview.substr(0,OFFSET) + chalk.red.bold(preview[OFFSET]) + preview.substr(OFFSET+1)
			preview = '\n'+chalk.dim(preview)
			syntaxErr.targetFile = filePath

			console.error(consoleLabels.error, preview, syntaxErr)
			return content


	transpileES6toES5: (code)-> if not code then code else
		transpiled = babel.transform(code, presets:'latest', ast:false).code
		transpiled = transpiled.replace(regEx.useStrict, '') unless regEx.useStrict.test(code)



	resolveModulePath: (moduleName, basedir)->
		moduleLoad = if moduleName.startsWith('/') or moduleName.includes('./') then Promise.resolve() else resolveModule(moduleName, {basedir, modules:coreModuleShims})
		moduleLoad
			.then (modulePath)=> Promise.resolve(modulePath)
			.catch (err)=> Promise.resolve()
			.then (modulePath)=> Promise.resolve(modulePath)


	isCoreModule: (moduleName)->
		coreModulesUnsupported.includes(moduleName)



dirListingCache = {}
module.exports = helpers