Promise = require 'bluebird'
promiseBreak = require 'p-break'
PATH = require 'path'
md5 = require 'md5'
fs = require 'fs-jetpack'
globMatch = require 'micromatch'
chalk = require 'chalk'
extend = require 'extend'
findPkgJson = require 'read-pkg-up'
Parser = require 'esprima'
helpers = require './helpers'
File = require './file'
LABELS = require './constants/consoleLabels'
EXTENSIONS = require './constants/extensions'
PRELUDE = require './constants/prelude'

class Task extends require('events')
	constructor: (options, @entryInput)->
		@currentID = -1
		@files = []
		@importStatements = []
		@cache = Object.create(null)
		@requiredGlobals = Object.create(null)
		
		@options = extendOptions(options)
		@options.context ?= if @options.isStream then process.cwd() else helpers.getNormalizedDirname(@entryInput)
		if @options.isStream
			@options.suppliedPath = PATH.resolve('main.'+ if @options.isCoffee then 'coffee' else 'js')
		else
			@options.suppliedPath = @entryInput = PATH.resolve(@entryInput)
			@options.isCoffee ?= PATH.extname(@entryInput).toLowerCase() is '.coffee'
		
		super
		@attachListeners()

	
	attachListeners: ()->
		@.on 'requiredGlobal', (file, varName)=>
			if varName.statsWith('__')
				file.requiredGlobals[varName] = true
			else
				@requiredGlobals[varName] = true
		
		@.on 'TokenizeError', (file, err)=>
			console.warn "#{LABELS.warn} Failed to tokenize #{chalk.dim file.filePathSimple}", require('stack-filter')(err.stack)
		
		@.on 'ASTParseError', (file, err)=>
			console.warn "#{LABELS.error} Failed to parse #{chalk.dim file.filePathSimple}", require('stack-filter')(err.stack)
		
		@.on 'ParseError', (file, err)=>
			console.warn "#{LABELS.error} Failed to parse #{chalk.dim file.filePathSimple}", require('stack-filter')(err.stack)
		
		@.on 'ExtractError', (file, err)=>
			console.warn "#{LABELS.error} Failed to parse #{chalk.dim file.filePathSimple}", require('stack-filter')(err.stack)
		
		@.on 'TokenError', (file, err)=>
			console.warn "#{LABELS.error} Failed to parse #{chalk.dim file.filePathSimple}", require('stack-filter')(err.stack)
		
		@.on 'GeneralError', (file, err)=>
			console.warn "#{LABELS.error} Failed to parse #{chalk.dim file.filePathSimple}", require('stack-filter')(err.stack)


	resolveEntryPackage: ()->
		### istanbul ignore next ###
		Promise.bind(@)
			.then ()-> findPkgJson(normalize:false, cwd:@options.context)
			.then (result)->
				helpers.resolvePackagePaths(result.pkg, result.path)
				@options.pkgFile = pkgFile = result.pkg
				
				unless @options.isStream
					@entryInput = pkgFile.browser[@entryInput] if typeof pkgFile.browser is 'object' and pkgFile.browser[@entryInput]

			.catch ()->


	resolveFilePath: (input)->
		Promise.bind(@)
			.then ()->
				extname = PATH.extname(input).slice(1).toLowerCase()
				if extname and EXTENSIONS.all.includes(extname)
					promiseBreak(input)
				else
					PATH.parse(input)
			
			.then (params)->
				helpers.getDirListing(params.dir, @options.dirCache).then (list)-> [params, list]
			
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
						promiseBreak PATH.join(params.dir, fileMatch)
					else #if exactMatch
						return params
			
			.then (params)->
				resolvedPath = PATH.join(params.dir, params.base)
				fs.inspectAsync(resolvedPath).then (stats)->
					if stats.type isnt 'dir'
						promiseBreak(resolvedPath)
					else
						return params

			.then (params)->
				helpers.getDirListing(PATH.join(params.dir, params.base), @options.dirCache).then (list)-> [params, list]

			.then ([params, dirListing])->
				indexFile = dirListing.find (file)-> file.includes('index')
				return PATH.join(params.dir, params.base, if indexFile then indexFile else 'index.js')

			.catch promiseBreak.end
			.then (filePath)->
				context = helpers.getNormalizedDirname(filePath)
				contextRel = context.replace(@entryFile.context+'/', '')
				filePathSimple = helpers.simplifyPath(filePath)
				filePathRel = filePath.replace(@entryFile.context+'/', '')
				fileExt = PATH.extname(filePath).toLowerCase().slice(1)
				fileExt = 'yml' if fileExt is 'yaml'
				fileBase = PATH.basename(filePath)
				suppliedPath = input
				return {filePath, filePathSimple, filePathRel, fileBase, fileExt, context, contextRel, suppliedPath}


	initEntryFile: ()->
		Promise.bind(@)
			.then ()-> promiseBreak(@entryInput) if @options.isStream
			.then ()-> fs.readAsync(@entryInput)
			.catch promiseBreak.end
			.then (content)->
				@entryFile = new File @, {
					ID: ++@currentID
					isEntry: true
					content: content
					hash: md5(content)
					options: @options.pkgFile.simplyimport?.main or {}
					pkgFile: @options.pkgFile
					suppliedPath: if @options.isStream then '' else @entryInput
					context: @options.context
					contextRel: '/'
					filePath: @options.suppliedPath
					filePathSimple: '*ENTRY*'
					filePathRel: '/main.js'
					fileExt: if @options.isCoffee then 'coffee' else 'js'
					fileBase: 'main.js'
				}

			.tap (file)->
				@files.push file


	initFile: (input, importer)->
		pkgFile = null
		Promise.bind(@)
			.then ()->
				helpers.resolveModulePath(input, importer.context, importer.filePath, importer.pkgFile)

			.then (module)->
				pkgFile = module.pkg
				return module.file
			
			.then @resolveFilePath
			.tap (config)-> promiseBreak(@cache[config.filePath]) if @cache[config.filePath]
			.tap (config)->
				fs.readAsync(config.filePath).then (content)->
					config.content = content
					config.hash = md5(content)

			.tap (config)-> promiseBreak(@cache[config.hash]) if @cache[config.hash]
			.tap (config)->
				config.ID = ++@currentID
				config.pkgFile = pkgFile or {}
				config.isExternal = config.pkgFile isnt @entryFile.pkgFile
				config.isExternalEntry = config.isExternal and config.pkgFile isnt importer.pkgFile
				specificOptions = if config.isExternal then extend({}, config.pkgFile.simplyimport, @options.fileSpecific) else @options.fileSpecific
				
				config.options = switch
					when specificOptions[config.suppliedPath] then specificOptions[config.suppliedPath]
					else do ()->
						matchingGlob = null
						opts = matchBase:true
						
						for glob of specificOptions
							if globMatch.isMatch(config.filePath, glob, opts) or
								globMatch.isMatch(config.filePath, glob) or
								globMatch.isMatch(config.filePathSimple, glob) or
								globMatch.isMatch(config.suppliedPath, glob, opts)
									matchingGlob = glob

						return specificOptions[matchingGlob] or {}
				
			
			.then (config)->
				new File(@, config)

			.tap (file)->
				@files.push file
			
			.catch promiseBreak.end


	processFile: (file)-> unless file.processed
		file.processed = true
		Promise.bind(file)
			.then file.checkIfIsThirdPartyBundle
			.then file.collectRequiredGlobals
			.then file.collectIgnoreRanges
			.then file.determineType
			.then file.tokenize
			.return(file))


	scanImports: (file, depth=Infinity, currentDepth=0)->
		file.scannedImports = true
		Promise.bind(@)
			.then ()-> file.collectImports()
			.tap (imports)-> @importStatements.push(imports...)
			.map (statement)->
				Promise.bind(@)
					.then ()-> @initFile(statement.target, file)
					.then (childFile)-> @processFile(childFile)
					.then (childFile)-> statement.target = childFile
					.return(statement)
			
			.tap ()-> promiseBreak(@importStatements) if ++currentDepth >= depth
			
			.filter (statement)-> not statement.target.scannedImports
			.map (statement)-> @scanImports(statement.target)
			.catch promiseBreak.end
			.return(@importStatements)


	scanExports: (file)->
		file.scannedExports = true
		Promise.bind(@)
			.then ()-> file.collectExports()
			.filter (statement)-> statement.target isnt statement.source
			.map (statement)->
				Promise.bind(@)
					.then ()-> @initFile(statement.target, file)
					.then (childFile)-> @processFile(childFile)
					.then (childFile)-> statement.target = childFile
					.return(statement)
						
			.filter (statement)-> not statement.target.scannedExports
			.map (statement)-> @scanExports(statement.target).then ()=> @scanImports(statement.target)
			.return(@importStatements



	calcImportTree: ()->
		Promise.bind(@)
			.then ()->
				@imports = @importStatements.groupBy('target.hash')

			.then ()->
				Object.values(@imports)
			
			.map (statements)->
				statements.slice().forEach (statement)-> if statement.conditions
					if not statement.conditions.every((condition)-> process.env[condition])
						statement.removed = true
						statements.remove(statement)

				if statements.unique('id').length > 1 or statements.some(helpers.isMixedExtStatement)
					targetType = 'module'

				Promise.map statements, (statement)=>
					statement.type = targetType or statement.target.type
					
					if statement.extract and statement.target.fileExt isnt 'json'
						Promise.bind(statement.target)
							.then statement.target.applyAllTransforms
							.then statement.target.saveContent
							.then ()=>
								if statement.target.fileExt isnt 'json'
									@emit 'ExtractError', statement.target, new Error "invalid attempt to extract data from a non-data file type"

			.then ()->
				@files.filter(isDataType:true).map (file)->
					statements = @imports[file.hash]
					someExtract = statements.some(s -> s.extract)
					allExtract = someExtract and statements.every(s -> s.extract)
					
					if statements.length > 1
						if allExtract
							extracts = statements.map('extract').unique()
							file.content = JSON.stringify new ()-> @[key] = file.extract(key) for key in extracts; @
						else if someExtract
							extracts = statements.filter(extract:/./).map('extract').unique()
							file.parsed[key] = file.extract(key) for key in extracts
							file.content = JSON.stringify file.parsed

						file.content = "module.exports = #{file.content}"


						
			
			.then ()-> @imports



	replaceInlineImports: (file)->
		return file if file.insertedInline
		file.insertedInline = true
		
		Promise.resolve(file.importStatements).bind(file)
			.map (statement)=> @replaceInlineImports(statement.target)
			.then file.replaceInlineImports
			.then file.saveContent
			.then file.saveContentMilestone.bind(file, 'contentPostInlinement')
			.return(file)

					


	compileFile: (file)->
		Promise.bind(file)
			.then file.replaceImportStatements
			.then file.saveContent
			.then file.replaceExportStatements
			.then file.saveContent
			.then file.applyAllTransforms
			.then file.saveContent
			.then file.saveContentMilestone.bind(file, 'contentPostTransforms')
			.then file.genAST
			.then file.adjustASTLocations

	
	compile: ()->
		Promise.bind(@)
			.then @calcImportTree
			.then @replaceInlineImports.bind(@, @entryFile)
			.return @files
			.filter (file)-> file.type isnt 'inline'
			.map @compileFile
			.then ()->
				bundleAST = do ()=>
					returnResult = if @options.umd then PRELUDE.umd(@options.umd) else PRELUDE.returnResult()
					args = []
					values = []
					if @requiredGlobals.global
						args.push 'global'
						values.push PRELUDE.globalDec()
					
					return Parser.parse PRELUDE.bundle(args, values, returnResult)

				loader = Parser.parse(PRELUDE.loader()).body[0]
				modules = loader.declarations[0].init.arguments[0].properties
				
				@files.sortBy('ID').forEach (file)-> modules.push
					type: 'Property'
					kind: 'init'
					computed: false
					method: false
					shorthand: false
					key:
						type: 'Literal'
						value: file.ID
						raw: String(file.ID)
				
					value: do ()->
						module = Parser.parseExpr "(#{PRELUDE.module()})"
						fnBody = module.callee.object.body.body
						returnExports = fnBody.pop()
						
						if Object.keys(file.requiredGlobals).length
							args = []; values = []
							
							if file.requiredGlobals.__filename
								args.push '__filename'
								values.push file.filePathRel
							
							if file.requiredGlobals.__dirname
								args.push '__dirname'
								values.push file.contextRel
							
							wrapper = Parser.parseExpr PRELUDE.moduleGlobals(args, values)
							fnBody.push wrapper
							fnBody = wrapper.callee.object.body.body
						
						fnBody.push file.AST.body...
						module.push returnExports
						return moudle

				bundleAST.body[0].expression.callee.object.body.unshift(loader)
				return bundleAST

			.then (ast)-> require('escodegen').generate(ast)


















### istanbul ignore next ###
extendOptions = (suppliedOptions)->
	options = extend({}, require('./defaultOptions'), suppliedOptions)
	options.conditions = [].concat(options.conditions) if options.conditions and not Array.isArray(options.conditions)
	options.transform = normalizeTransformOpts(options.transform) if options.transform
	options.globalTransform = normalizeTransformOpts(options.globalTransform) if options.globalTransform
	for p,specificOpts of options.fileSpecific
		specificOpts.transform = normalizeTransformOpts(specificOpts.transform) if specificOpts.transform
	
	return options


normalizeTransformOpts = (transform)->
	transform = [].concat(transform) if transform and not Array.isArray(transform)
	if transform.length is 2 and typeof transform[0] is 'string' and require('is-plain-obj')(transform[1])
		transform = [transform]

	return transform








module.exports = Task