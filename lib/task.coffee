Promise = require 'bluebird'
promiseBreak = require 'promise-break'
Path = require 'path'
md5 = require 'md5'
fs = require 'fs-jetpack'
globMatch = require 'micromatch'
chalk = require 'chalk'
extend = require 'extend'
findPkgJson = require 'read-pkg-up'
formatError = require './external/formatError'
Parser = require './external/parser'
helpers = require './helpers'
File = require './file'
LABELS = require './constants/consoleLabels'
EXTENSIONS = require './constants/extensions'

class Task extends require('events')
	constructor: (options)->
		options = file:options if typeof options is 'string'
		throw new Error("either options.file or options.src must be provided") if not options.file and not options.src
		@entryInput = options.file or options.src
		@currentID = -1
		@files = []
		@importStatements = []
		@cache = Object.create(null)
		@requiredGlobals = Object.create(null)
		
		@options = extendOptions(options)
		@options.context ?= if @options.file then helpers.getNormalizedDirname(@entryInput) else process.cwd()
		if @options.file
			@options.ext = Path.extname(@entryInput).replace('.','') or 'js'
			@options.suppliedPath = @entryInput = Path.resolve(@entryInput)
		else
			@options.ext ?= 'js'
			@options.suppliedPath = Path.resolve("entry.#{@options.ext}")
		
		super
		@attachListeners()

	
	attachListeners: ()->
		@.on 'requiredGlobal', (file, varName)=>
			if varName.statsWith('__')
				file.requiredGlobals[varName] = true
			else
				@requiredGlobals[varName] = true
		
		@.on 'TokenizeError', (file, err)=>
			throw formatError "#{LABELS.error} Failed to tokenize #{chalk.dim file.filePathSimple}", err
		
		@.on 'ASTParseError', (file, err)=>
			throw formatError "#{LABELS.error} Failed to parse #{chalk.dim file.filePathSimple}", err
		
		@.on 'DataParseError', (file, err)=>
			throw formatError "#{LABELS.error} Failed to parse #{chalk.dim file.filePathSimple}", err
		
		@.on 'ExtractError', (file, err)=>
			throw formatError "#{LABELS.error} Extraction error in #{chalk.dim file.filePathSimple}", err
		
		@.on 'TokenError', (file, err)=>
			throw formatError "#{LABELS.error} Bad token #{chalk.dim file.filePathSimple}", err
		
		@.on 'SyntaxError', (file, err)=>
			err.message = err.annotated.lines().slice(1, -1).append('',0).join('\n')
			Error.captureStackTrace(err)
			throw formatError "#{LABELS.error} Invalid syntax in #{chalk.dim file.filePathSimple+':'+err.line+':'+err.column}", err
		
		@.on 'GeneralError', (file, err)=>
			throw formatError "#{LABELS.error} Error while processing #{chalk.dim file.filePathSimple}", err


	resolveEntryPackage: ()->
		### istanbul ignore next ###
		Promise.bind(@)
			.then ()-> findPkgJson(normalize:false, cwd:@options.context)
			.then (result)->
				helpers.resolvePackagePaths(result.pkg, result.path)
				@options.pkgFile = pkgFile = result.pkg
				
				unless @options.src
					@entryInput = pkgFile.browser[@entryInput] if typeof pkgFile.browser is 'object' and pkgFile.browser[@entryInput]

			.catch ()->



	initEntryFile: ()->
		Promise.bind(@)
			.then ()-> promiseBreak(@entryInput) if @options.src
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
					suppliedPath: if @options.src then '' else @entryInput
					context: @options.context
					contextRel: '/'
					filePath: @options.suppliedPath
					filePathSimple: helpers.simplifyPath(@options.suppliedPath)
					filePathRel: '/entry.js'
					fileExt: @options.ext
					fileBase: 'entry.js'
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
			
			.then (input)->
				helpers.resolveFilePath(input, @entryFile.context, pkgFile is importer.pkgFile)
			
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
			.then file.collectConditionals
			.then ()=> @scanForceInlineImports(file)
			.then ()=> @replaceForceInlineImports(file)
			.then file.applyAllTransforms
			.then file.saveContent
			.then file.saveContentMilestone.bind(file, 'contentPostTransforms')
			.then file.checkSyntaxErrors
			.then file.checkIfIsThirdPartyBundle
			.then file.collectRequiredGlobals
			.then file.determineType
			.then file.tokenize
			.return(file)


	scanForceInlineImports: (file)->
		file.scannedForceInlineImports = true
		Promise.bind(@)
			.then ()-> file.collectForceInlineImports()
			.tap (imports)-> @importStatements.push(imports...)
			.map (statement)->
				Promise.bind(@)
					.then ()-> @initFile(statement.target, file)
					.then (childFile)-> @processFile(childFile)
					.then (childFile)-> statement.target = childFile
					.return(statement)
			
			.filter (statement)-> not statement.target.scannedForceInlineImports
			.map (statement)-> @scanForceInlineImports(statement.target)
			.catch promiseBreak.end
			.return(@importStatements)


	scanImports: (file, depth=Infinity, currentDepth=0)->
		file.scannedImports = true
		Promise.bind(@)
			.then ()-> file.collectImports()
			.filter (statement)-> statement.type isnt 'inline-forced'
			.tap (imports)-> @importStatements.push(imports...)
			.map (statement)->
				Promise.bind(@)
					.then ()-> @initFile(statement.target, file)
					.then (childFile)-> @processFile(childFile)
					.then (childFile)-> statement.target = childFile
					.return(statement)
			
			.tap ()-> promiseBreak(@importStatements) if ++currentDepth >= depth
			
			.filter (statement)-> not statement.target.scannedImports
			.map (statement)-> @scanImports(statement.target, depth, currentDepth)
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
			.return(@importStatements)



	calcImportTree: ()->
		Promise.bind(@)
			.then ()->
				@imports = @importStatements.groupBy('target.hash')

			.then ()->
				Object.values(@imports)
			
			.map (statements)->
				statements = statements.filter (statement)-> statement.type isnt 'inline-forced'
				statements.slice().forEach (statement)-> if statement.conditions
					if not statement.conditions.every((condition)-> process.env[condition])
						statement.removed = true
						statements.remove(statement)

				if statements.length > 1 or statements.some(helpers.isMixedExtStatement)
					targetType = 'module'

				Promise.map statements, (statement)=>
					statement.type = targetType or statement.target.type
					
					if statement.extract and statement.target.fileExt isnt 'json'
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



	replaceForceInlineImports: (file)->
		return file if file.insertedForceInline
		file.insertedForceInline = true
		
		Promise.resolve(file.importStatements).bind(file)
			.map (statement)=> @replaceForceInlineImports(statement.target)
			.then file.replaceForceInlineImports
			.then file.saveContent
			.then file.saveContentMilestone.bind(file, 'contentPostForceInlinement')



	replaceInlineImports: (file, skipModules)->
		return file if file.insertedInline
		file.insertedInline = true
		targetStatements =
			if skipModules
				file.importStatements.filter(type:'inline')
			else
				file.importStatements
		
		Promise.resolve(file.importStatements).bind(file)
			.map (statement)=> @replaceInlineImports(statement.target)
			.return(null)
			.then file.replaceInlineImports
			.then file.saveContent
			.then file.saveContentMilestone.bind(file, 'contentPostInlinement')
			.return(file)

					


	compileFile: (file)->
		Promise.resolve(file.content).bind(file)
			.then file.replaceImportStatements
			.then file.saveContent
			.then file.replaceExportStatements
			.then file.saveContent
			.then file.genAST
			.then file.adjustASTLocations
			.return(file)

	
	compile: ()->		
		Promise.bind(@)
			.then @calcImportTree
			.return @entryFile
			.then @replaceInlineImports
			.then ()->
				@importStatements
					.filter(type:'module')
					.unique('target')
					.map('target')
					.append(@entryFile, 0)
			
			.map @compileFile
			.then (files)->
				if files.length is 1
					return promiseBreak(@entryFile.AST)

				bundle = builders.bundle(@options.umd, @requiredGlobals)
				{loader, modules} = builders.loader()
				
				files.sortBy('ID').forEach (file)->
					modules.push builders.moduleProp(file)

				bundle.body[0].expression.callee.object.body.unshift(loader)
				return bundle

			.catch promiseBreak.end
			.then (ast)-> Parser.generate(ast)
			.tap ()-> setTimeout @destroy.bind(@)


	destroy: ()->
		file.destroy() for file in @files
		@removeAllListeners()
		@files.length = 0
		@importStatements.length = 0
		delete @files
		delete @importStatements
		delete @imports
		delete @cache
		delete @options
		delete @requiredGlobals


















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
	if transform.length is 2 and typeof transform[0] is 'string' and Object.isObject(transform[1])
		transform = [transform]

	return transform








module.exports = Task