Promise = require 'bluebird'
promiseBreak = require 'promise-break'
Path = require 'path'
md5 = require 'md5'
fs = require 'fs-jetpack'
chalk = require 'chalk'
extend = require 'extend'
formatError = require './external/formatError'
Parser = require './external/parser'
helpers = require './helpers'
File = require './file'
REGEX = require './constants/regex'
LABELS = require './constants/consoleLabels'
EXTENSIONS = require './constants/extensions'
debug = require('debug')('simplyimport')
EMPTY_STUB = Path.join __dirname,'..','empty.js'

class Task extends require('events')
	constructor: (options)->
		options = file:options if typeof options is 'string'
		throw new Error("either options.file or options.src must be provided") if not options.file and not options.src
		@entryInput = options.file or options.src
		@currentID = -1
		@files = []
		@importStatements = []
		@cache = Object.create(null)
		@dirCache = Object.create(null)
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
			if varName isnt 'global' #if varName.startsWith('__')
				file.requiredGlobals[varName] = true
			else
				@requiredGlobals[varName] = true

		@.on 'missingImport', (file, target, pos)->
			annotation = helpers.annotateErrLocation(file, pos)
			if @options.ignoreMissing
				console.warn "#{LABELS.warn} cannot find '#{chalk.yellow target}'", annotation
			else
				@throw formatError "#{LABELS.error} cannot find '#{chalk.yellow target}'", helpers.blankError(annotation)

		@.on 'missingEntry', ()=>
			throw formatError "#{LABELS.error} cannot find '#{chalk.yellow @options.file}'", helpers.blankError()

		@.on 'TokenizeError', (file, err)=>
			@throw formatError "#{LABELS.error} Failed to tokenize #{file.pathDebug}", err
		
		@.on 'ASTParseError', (file, err)=>
			@throw formatError "#{LABELS.error} Failed to parse #{file.pathDebug}", err
		
		@.on 'DataParseError', (file, err)=>
			if pos = err.message.match(/at position (\d+)/)?[1]
				err.message += helpers.annotateErrLocation(file, pos)
			@throw formatError "#{LABELS.error} Failed to parse #{file.pathDebug}", err
		
		@.on 'ExtractError', (file, err)=>
			@throw formatError "#{LABELS.error} Extraction error in #{file.pathDebug}", err
		
		@.on 'TokenError', (file, err)=>
			err.message += helpers.annotateErrLocation(file, err.token.start)
			@throw formatError "#{LABELS.error} Unexpected token #{file.pathDebug}", err
		
		@.on 'SyntaxError', (file, err)=> unless @options.ignoreSyntaxErrors
			err.message = err.annotated.lines().slice(1, -1).append('',0).join('\n')
			Error.captureStackTrace(err)
			@throw formatError "#{LABELS.error} Invalid syntax in #{chalk.dim file.path+':'+err.line+':'+err.column}", err
		
		@.on 'ConditionalError', (file, err, posStart, posEnd)=>
			err ?= helpers.blankError helpers.annotateErrLocation(file, posStart, posEnd)
			@throw formatError "#{LABELS.error} Invalid conditional syntax in #{file.pathDebug}", err
		
		@.on 'TransformError', (file, err, transformer)=>
			name = chalk.dim transformer.name or String transformer.fn
			@throw formatError "#{LABELS.error} Error while applying transform #{name} to #{file.pathDebug}", err
		
		@.on 'GeneralError', (file, err)=>
			throw err if err.message.startsWith(LABELS.error)
			throw formatError "#{LABELS.error} Error while processing #{file.pathDebug}", err


	throw: (err)->
		throw err unless @options.ignoreErrors


	handleMissingFile: (file, statement)->
		@emit 'missingImport', file, statement.target, statement.range[0]

		Promise.bind(@)
			.then ()-> @initFile EMPTY_STUB, file, false, false
			.then (emptyFile)->
				statement.target = emptyFile
				statement.extract = undefined


	initEntryFile: ()->
		Promise.bind(@)
			.then ()-> helpers.resolveEntryPackage(@)
			.then (pkgFile)->
				if pkgFile and pkgFile['simplyimport:specific'] and Object.keys(@options.specific).length is 0
					@options.specific = normalizeSpecificOpts(pkgFile['simplyimport:specific'])
			
			.then ()-> promiseBreak(@entryInput) if @options.src
			.then ()-> fs.existsAsync(@entryInput).then (exists)=> if not exists then @emit 'missingEntry'
			.then ()-> fs.readAsync(@entryInput)
			.catch promiseBreak.end
			.then (content)->
				path = helpers.simplifyPath(@options.suppliedPath)
				base = if @options.file then Path.basename(@options.file) else 'entry.js'
				config =
					ID: if @options.usePaths then 'entry.js' else ++@currentID
					isEntry: true
					content: content
					hash: md5(content)
					pkgFile: @options.pkgFile
					suppliedPath: if @options.src then '' else @entryInput
					context: @options.context
					contextRel: ''
					pathAbs: @options.suppliedPath
					path: path
					pathDebug: chalk.dim(path)
					pathRel: base
					pathExt: @options.ext
					pathBase: base
				
				config.options = @options.specific.entry
				config.options ||= helpers.matchFileSpecificOptions(config, @options.specific) if @options.file
				config.options ||= {}
				@entryFile = new File @, config

			.tap (file)->
				@files.push file


	initFile: (input, importer, isForceInlined, prev=@prevFileInit)->
		suppliedPath = input
		pkgFile = null

		@prevFileInit =
		Promise.resolve(prev).bind(@)
			.then ()->
				helpers.resolveModulePath(input, importer.context, importer.pathAbs, importer.pkgFile)

			.then (module)->
				pkgFile = module.pkg
				return module.file
			
			.then (input)->
				helpers.resolveFilePath(input, @entryFile.context, (@dirCache if pkgFile is importer.pkgFile))
			
			.tap (config)-> debug "creating #{config.pathDebug}"
			.tap (config)->
				if @cache[config.pathAbs]
					debug "using cached #{config.pathDebug}"
					promiseBreak(@cache[config.pathAbs])

			.tap (config)->
				fs.existsAsync(config.pathAbs).then (exists)->
					throw new Error('missing') if not exists
			
			.tap (config)->
				fs.readAsync(config.pathAbs).then (content)->
					config.content = content
					config.hash = md5(content)

			.tap (config)->
				config.ID =
					if isForceInlined then 'inline-forced'
					else if @options.usePaths then config.pathRel
					else ++@currentID
				config.type = config.ID if isForceInlined
				config.suppliedPath = suppliedPath
				config.pkgFile = pkgFile or {}
				config.isExternal = config.pkgFile isnt @entryFile.pkgFile
				config.isExternalEntry = config.isExternal and config.pkgFile isnt importer.pkgFile
				specificOptions = if config.isExternal then extend({}, config.pkgFile.simplyimport, @options.specific) else @options.specific
				config.options = helpers.matchFileSpecificOptions(config, specificOptions)
				
			
			.then (config)->
				new File(@, config)
			.tap (config)-> debug "created #{config.pathDebug}"
			.tap (file)->
				@files.push file
			
			.catch promiseBreak.end


	processFile: (file)-> if file.processed then file else
		file.processed = true
		Promise.bind(file)
			.then file.collectConditionals
			.then ()=> @scanForceInlineImports(file)
			.then ()=> @replaceForceInlineImports(file)
			.then file.replaceES6Imports
			.then file.applyAllTransforms
			.then file.saveContentMilestone.bind(file, 'contentPostTransforms')
			.tap ()-> promiseBreak() if file.type is 'inline-forced'
			.then file.checkSyntaxErrors
			.catch promiseBreak.end
			.then file.restoreES6Imports
			.then file.checkIfIsThirdPartyBundle
			.then file.collectRequiredGlobals
			.then file.postTransforms
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
					.then ()-> @initFile(statement.target, file, true)
					.then (childFile)-> @processFile(childFile)
					.then (childFile)-> statement.target = childFile
					.catch message:'missing', @handleMissingFile.bind(@, file, statement)
					.return(statement)
			
			.filter (statement)-> not statement.target.scannedForceInlineImports
			.map (statement)-> @scanForceInlineImports(statement.target)
			.catch promiseBreak.end
			.catch (err)-> @emit 'GeneralError', file, err
			.return(@importStatements)


	scanImportsExports: (file, depth=Infinity, currentDepth=0)-> if not file.scannedImportsExports
		file.scannedImportsExports = true
		importingExports = null
		
		Promise.bind(@)
			.then ()-> file.collectExports()
			.filter (statement)-> statement.target isnt statement.source
			.tap (exports)-> @importStatements.push(exports...); importingExports = exports
			
			.then ()-> file.collectImports()
			.filter (statement)-> statement.type isnt 'inline-forced'
			.tap (imports)-> @importStatements.push(imports...)
			
			.then (imports)-> imports.concat(importingExports)
			.map (statement)->
				Promise.bind(@)
					.then ()-> @initFile(statement.target, file)
					.then (childFile)-> @processFile(childFile)
					.then (childFile)-> statement.target = childFile
					.catch message:'missing', @handleMissingFile.bind(@, file, statement)
					.return(statement)
			
			.tap ()-> promiseBreak(@importStatements) if ++currentDepth >= depth
			.map (statement)-> @scanImportsExports(statement.target, depth, currentDepth)
			
			.catch promiseBreak.end
			.catch (err)-> @emit 'GeneralError', file, err
			.return(@importStatements)



	calcImportTree: ()->
		Promise.bind(@)
			.then ()->
				@imports = @importStatements.groupBy('target.pathAbs')

			.then ()->
				Object.values(@imports)
			
			.map (statements)->
				statements = statements.filter (statement)-> statement.type isnt 'inline-forced'

				if statements.length > 1 or statements.some(helpers.isMixedExtStatement) or statements.some(helpers.isRecursiveImport)
					targetType = 'module'

				Promise.map statements, (statement)=>
					statement.type = targetType or statement.target.type

					if statement.extract and statement.target.pathExt isnt 'json'
						@emit 'ExtractError', statement.target, new Error "invalid attempt to extract data from a non-data file type"

					if statement.type is 'module' and statement.target.type is 'inline' and not statement.target.becameModule
						statement.target.becameModule = true
						statement.target.content = helpers.exportLastExpression(statement.target)

			.then ()->
				@files.filter(isDataType:true).map (file)=>
					statements = @imports[file.pathAbs]
					someExtract = statements.some((s)-> s.extract)
					allExtract = someExtract and statements.every((s)-> s.extract)

					if statements.length > 1
						if someExtract and REGEX.commonExport.test(file.content)
							file.content = file.content.replace(REGEX.commonExport, '').replace(REGEX.endingSemi, '')
						

						if allExtract
							extracts = statements.map('extract').unique()
							file.content = JSON.stringify new ()-> @[key] = file.extract(key, true) for key in extracts; @
						
						else if someExtract
							extracts = statements.filter((s)-> s.extract).map('extract').unique()
							for key in extracts
								extract = file.extract(key,true)
								file.parsed[key] = extract
							file.content = JSON.stringify file.parsed

						file.content = "module.exports = #{file.content}"


			.then ()->
				return if not @options.dedupe
				dupGroups = @importStatements.groupBy('target.hashPostTransforms')
				dupGroups = Object.filter dupGroups, (group)-> group.length > 1
				
				for h,group of dupGroups
					for statement,index in group when index > 0
						statement.target = group[0].target
				return
			
			.then ()-> @imports



	replaceForceInlineImports: (file)->
		return file if file.insertedForceInline
		file.insertedForceInline = true
		
		Promise.resolve(file.importStatements).bind(file)
			.map (statement)=> @replaceForceInlineImports(statement.target)
			.then file.replaceForceInlineImports
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
			.tap ()-> debug "replacing inline imports #{file.pathDebug}"
			.then file.replaceInlineImports
			.then file.saveContentMilestone.bind(file, 'contentPostInlinement')
			.return(file)

	
	replaceImportsExports: (file)->
		return file if file.replacedImportsExports
		file.replacedImportsExports = true
		
		Promise.resolve(file.content).bind(file)
			.tap ()-> debug "replacing imports/exports #{file.pathDebug}"
			.then file.replaceImportStatements
			.then file.saveContent
			.then file.replaceExportStatements
			.then file.saveContent
			.return file.importStatements.concat(file.exportStatements)
			.filter (statement)-> statement.type isnt 'inline-forced'
			.map (statement)=> @replaceImportsExports(statement.target)
			.return(file)


	genSourceMap: (file)->
		Promise.resolve(file.content).bind(file)
			.tap ()-> debug "generating sourcemap #{file.pathDebug}"
			.then ()-> promiseBreak() if not @options.sourceMap
			.then file.genAST
			.then file.genSourceMap
			.then file.adjustSourceMap
			.catch promiseBreak.end
			.return(file)

	
	compile: ()->
		builders = require('./builders')
		
		Promise.bind(@)
			.then @calcImportTree
			.return @entryFile
			.then @replaceImportsExports
			.then @replaceInlineImports
			.then ()->
				@importStatements
					.filter (statement)=> statement.type is 'module' and statement.target isnt @entryFile
					.unique('target')
					.map('target')
					.append(@entryFile, 0)
					.sortBy('hash')
			
			.tap (files)-> promiseBreak(@entryFile.content) if files.length is 1 and @entryFile.type isnt 'module' and Object.keys(@requiredGlobals).length is 0
			.then (files)->
				bundle = builders.bundle(@)
				{loader, modules} = builders.loader()
				
				files.sortBy('hash').forEach (file)->
					modules.push builders.moduleProp(file)

				bundle.body[0].expression.callee.object.expression.body.body.unshift(loader)
				return bundle

			.then (ast)-> Parser.generate(ast)
			.catch promiseBreak.end
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
	options = extend({}, require('./defaults'), suppliedOptions)
	options.sourceMap ?= options.debug
	options.transform = normalizeTransformOpts(options.transform) if options.transform
	options.globalTransform = normalizeTransformOpts(options.globalTransform) if options.globalTransform
	options.specific = normalizeSpecificOpts(options.specific)
	
	return options


normalizeSpecificOpts = (specificOpts)->
	for p,fileSpecific of specificOpts when fileSpecific.transform
		fileSpecific.transform = normalizeTransformOpts(fileSpecific.transform)

	return specificOpts


normalizeTransformOpts = (transform)->
	transform = [transform] if transform and not Array.isArray(transform)
	if transform.length is 2 and typeof transform[0] is 'string' and Object.isObject(transform[1])
		transform = [transform]

	return transform








module.exports = Task