Promise = require 'bluebird'
promiseBreak = require 'promise-break'
Path = require './helpers/path'
stringHash = require 'string-hash'
fs = require 'fs-jetpack'
chalk = require 'chalk'
extend = require 'extend'
formatError = require './external/formatError'
parser = require './external/parser'
helpers = require './helpers'
File = require './file'
SourceMapCombiner = require './sourceMapCombiner'
REGEX = require './constants/regex'
LABELS = require './constants/consoleLabels'
EXTENSIONS = require './constants/extensions'
BUILTINS = require('./constants/coreShims').builtins
debug = require('debug')('simplyimport:task')
{EMPTY_STUB} = require('./constants')

class Task extends require('events')
	constructor: (options)->
		options = file:options if typeof options is 'string'
		throw new Error("either options.file or options.src must be provided") if not options.file and not options.src
		@currentID = -1
		@ID = helpers.randomVar()
		@files = []
		@statements = []
		@inlineStatements = []
		@cache = Object.create(null)
		@requiredGlobals = Object.create(null)
		
		@options = extendOptions(options)
		@options.sourceMap = false # temporary until sourcemaps are fixed
		@options.context ?= if @options.file then helpers.getNormalizedDirname(@options.file) else process.cwd()
		if @options.file
			@options.ext = Path.extname(@options.file).replace('.','') or 'js'
			@options.suppliedPath = Path.resolve(@options.file)
		else
			@options.ext ?= 'js'
			@options.suppliedPath = Path.resolve("entry.#{@options.ext}")

		super
		@attachListeners()
		debug "new task created"

	
	attachListeners: ()->
		@.on 'requiredGlobal', (file, varName)=>
			if varName isnt 'global' #if varName.startsWith('__')
				file.requiredGlobals[varName] = true
			else
				@requiredGlobals[varName] = true

		@.on 'missingImport', (file, target, pos)->
			annotation = helpers.annotateErrLocation(file, pos)
			if @options.ignoreMissing
				console.warn "#{LABELS.warn} cannot find '#{chalk.yellow target}'", annotation unless @options.ignoreErrors
			else
				@throw formatError "#{LABELS.error} cannot find '#{chalk.yellow target}'", helpers.blankError(annotation)

		@.on 'missingEntry', ()=>
			throw formatError "#{LABELS.error} cannot find '#{chalk.yellow @options.file}'", helpers.blankError()
		
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
			err.message = err.annotated.split('\n').slice(1, -1).append('',0).join('\n')
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


	handleExcludedFile: (file, statement)->
		file.excluded = true


	handleIgnoredFile: (file, statement)->
		Promise.bind(@)
			.then ()-> @initFile EMPTY_STUB, file, false, false
			.then (emptyFile)->
				statement.target = emptyFile
				statement.extract = undefined


	handleMissingFile: (file, statement)->
		@emit 'missingImport', file, statement.target, statement.range.start

		Promise.bind(@)
			.then ()-> @initFile EMPTY_STUB, file, false, false
			.then (emptyFile)->
				statement.target = emptyFile
				statement.extract = undefined


	initEntryFile: ()->
		Promise.bind(@)
			.tap ()-> debug "start entry file init"
			.then ()-> helpers.resolveEntryPackage(@)
			.then (pkg)->
				unless @options.noPkgConfig
					@options = extend true, normalizeOptions(pkg.simplyimport), @options if Object.isObject(pkg?.simplyimport)

				@shims = pkg.browser = switch
					when @options.target is 'node' then {}
					when typeof pkg.browser is 'undefined' then {}
					when typeof pkg.browser is 'string' then {"#{pkg.main}":pkg.browser}
					when typeof pkg.browser is 'object' then extend(true, {}, pkg.browser)
			
			.then ()-> @options.env = normalizeEnv(@options.env, @options.pkg.dirPath) # we do this here to allow loading of option from package.json
			.then ()-> promiseBreak(@options.src) if @options.src
			.then ()-> fs.existsAsync(@options.file).then (exists)=> if not exists then @emit 'missingEntry'
			.then ()-> fs.readAsync(@options.file)
			.catch promiseBreak.end
			.then (content)->
				path = helpers.simplifyPath(@options.suppliedPath)
				base = if @options.file then Path.basename(@options.file) else 'entry.js'
				config =
					ID: if @options.usePaths then 'entry.js' else ++@currentID
					isEntry: true
					content: content
					hash: stringHash(content)
					pkg: @options.pkg
					suppliedPath: @options.file or ''
					context: @options.context
					contextRel: ''
					pathAbs: @options.suppliedPath
					path: path
					pathDebug: chalk.dim(path)
					pathRel: base
					pathExt: @options.ext
					pathBase: base
					pathName: 'entry'
				
				config.options = @options.specific.entry
				config.options ||= helpers.matchFileSpecificOptions(config, @options.specific) if @options.file
				config.options ||= {}
				@entryFile = new File @, config

			.tap (file)->
				@files.push file
			.tap ()-> debug "done entry file init"


	initFile: (input, importer, isForceInlined, prev=@prevFileInit)->
		suppliedPath = input
		pkg = null

		@prevFileInit = thisFileInit = 
		Promise.resolve(prev).bind(@)
			.catch ()-> null # If prev was rejected with ignored/missing error
			.tap ()-> debug "start file init for #{chalk.dim input}"
			.then ()->
				helpers.resolveModulePath(input, importer, @options.target)

			.then (module)->
				pkg = module.pkg
				return module.file

			.then (input)->
				helpers.resolveFilePath(input, importer, @entryFile.context, suppliedPath)
			
			.tap (config)-> debug "start file init #{config.pathDebug}"
			.tap (config)->
				if @cache[config.pathAbs]
					debug "using cached file for #{config.pathDebug}"
					promiseBreak(@cache[config.pathAbs])
				else
					@cache[config.pathAbs] = thisFileInit
					return

			.tap (config)->
				config.pkg = pkg or {}
				config.isExternal = config.pkg isnt @entryFile.pkg
				config.isExternalEntry = config.isExternal and config.pkg isnt importer.pkg

			.tap (config)-> throw new Error('excluded') if helpers.matchGlob(config, @options.excludeFile) or config.isExternal and not @options.bundleExternal or @options.target is 'node' and BUILTINS.includes(suppliedPath)
			.tap (config)-> throw new Error('ignored') if helpers.matchGlob(config, @options.ignoreFile)
			.tap (config)-> throw new Error('missing') if not fs.exists(config.pathAbs)

			.tap (config)->
				config.ID =
					if isForceInlined then 'inline-forced'
					else if @options.usePaths then config.pathRel
					else ++@currentID
				config.type = config.ID if isForceInlined
				specificOptions = if config.isExternal then extend({}, config.pkg.simplyimport, @options.specific) else @options.specific
				config.options = helpers.matchFileSpecificOptions(config, specificOptions)
			
			.tap (config)->
				fs.readAsync(config.pathAbs).then (content)->
					config.content = content
					config.hash = stringHash(content)
				
			.then (config)-> new File(@, config)
			
			.tap (config)-> debug "done file init #{config.pathDebug}"
			.tap (file)-> @files.push file
			.catch promiseBreak.end


	processFile: (file)-> if file.processed then file.processed else
		file.processed =
		Promise.bind(file)
			.tap ()-> debug "processing #{file.pathDebug}"
			.then file.collectConditionals
			.then ()=> @scanInlineStatements(file)
			.then ()=> @replaceInlineStatements(file)
			.tap ()-> promiseBreak() if file.type is 'inline-forced'
			.then file.replaceES6Imports
			.then file.applyAllTransforms
			.then file.replaceES6Imports
			.then file.checkSyntaxErrors
			.then file.restoreES6Imports
			.then file.runChecks
			.then(file.collectRequiredGlobals unless @options.target is 'node')
			.then file.postTransforms
			.then file.determineType
			.then file.parse
			.catch promiseBreak.end
			.tap ()-> debug "done processing #{file.pathDebug}"
			.return(file)


	scanInlineStatements: (file)->
		file.scannedForceInlineImports = true
		Promise.bind(@)
			.then ()-> file.collectForceInlineImports()
			.tap (imports)-> @inlineStatements.push(imports...)
			.map (statement)->
				Promise.bind(@)
					.then ()-> @initFile(statement.target, file, true)
					.then (childFile)-> @processFile(childFile)
					.then (childFile)-> statement.target = childFile
					.catch message:'excluded', ()-> statement.type = 'inline-forced'; statement.kind = 'excluded'
					.catch message:'ignored', @handleIgnoredFile.bind(@, file, statement)
					.catch message:'missing', @handleMissingFile.bind(@, file, statement)
					.return(statement)
			
			.filter (statement)-> statement.kind isnt 'excluded' and not statement.target.scannedForceInlineImports
			.map (statement)-> @scanInlineStatements(statement.target)
			.catch promiseBreak.end
			.catch (err)-> @emit 'GeneralError', file, err
			.return(@inlineStatements)


	scanStatements: (file, depth=Infinity, currentDepth=0)-> if not file.scannedImportsExports
		file.scannedImportsExports = true
		importingExports = null
		collected = []
		
		Promise.bind(@)
			.then ()-> file.collectImports()
			.tap (imports)-> collected.push(imports...)
			
			.then ()-> file.collectExports()
			.filter (statement)-> statement.target isnt statement.source
			.tap (exports)-> collected.push(exports...)

			.tap ()-> file.resolveNestedStatements()
			
			.then ()-> @statements.push(collected...)
			.return collected
			.map (statement)->
				Promise.bind(@)
					.then ()-> @initFile(statement.target, statement.source)
					.tap (childFile)-> resetFile(childFile) if childFile.type is 'inline-forced'
					.then (childFile)-> @processFile(childFile)
					.then (childFile)-> statement.target = childFile
					.catch message:'excluded', ()-> statement.type = 'module'; statement.kind = 'excluded'
					.catch message:'ignored', @handleIgnoredFile.bind(@, statement.source, statement)
					.catch message:'missing', @handleMissingFile.bind(@, statement.source, statement)
					.return(statement)
			
			.tap ()-> promiseBreak(@statements) if ++currentDepth > depth
			.map (statement)-> @scanStatements(statement.target, depth, currentDepth) unless statement.kind is 'excluded'
			.then ()-> file.postScans()
			
			.catch promiseBreak.end
			.catch (err)-> @emit 'GeneralError', file, err
			.return(@statements)



	calcImportTree: ()->
		Promise.bind(@)
			.tap ()-> debug "start calculating import tree"
			.then ()-> @imports = @statements.concat(@inlineStatements).groupBy('target.pathAbs')

			.then ()-> Object.values(@imports)
			
			.map (statements)-> # determine statement types
				statements = statements.filter (statement)-> statement.kind isnt 'excluded'

				if statements.length > 1 or statements.some(helpers.isMixedExtStatement) or statements.some(helpers.isRecursiveImport)
					targetType = 'module'

				Promise.map statements, (statement)=>
					statement.type = targetType or statement.target.type

					if statement.extract and statement.target.pathExt isnt 'json'
						@emit 'ExtractError', statement.target, new Error "invalid attempt to extract data from a non-data file type"

					requiresModification = 
						statement.type is 'module' and
						statement.target.type is 'inline' and
						not statement.target.becameModule and
						not statement.target.path isnt EMPTY_STUB
					
					if requiresModification
						statement.target.exportLastExpression()
						statement.target.becameModule = true

			
			.then ()-> # perform data extractions
				dataFiles = @files.filter (file)=> file.isDataType and @imports[file.pathAbs]
				dataFiles.map (file)=>
					statements = @imports[file.pathAbs]
					someExtract = statements.some((s)-> s.extract)
					allExtract = someExtract and statements.every((s)-> s.extract)

					if statements.length > 1
						if someExtract and REGEX.commonExport.test(file.content)
							file.setContent file.ast.content.replace(REGEX.commonExport, '').replace(REGEX.endingSemi, '')
						

						if allExtract
							extracts = statements.map('extract').unique()
							file.setContent JSON.stringify new ()-> @[key] = file.extract(key, true) for key in extracts; @
						
						else if someExtract
							extracts = statements.filter((s)-> s.extract).map('extract').unique()
							for key in extracts
								extract = file.extract(key,true)
								file.parsed[key] = extract
							file.setContent JSON.stringify file.parsed

						file.setContent "module.exports = #{file.content}"


			.then ()-> # perform dedupe
				return if not @options.dedupe
				dupGroups = @statements.filter((s)-> s.kind isnt 'excluded').groupBy('target.hashPostTransforms')
				dupGroups = Object.filter dupGroups, (group)-> group.length > 1
				
				for h,group of dupGroups
					continue if group.some((s)-> s.target.options.dedupe is false)
					for statement,index in group when index > 0
						statement.target = group[0].target
				return
			
			.then ()-> @imports
			.tap ()-> debug "done calculating import tree"



	replaceInlineStatements: (file)->
		return file if file.replacedInlineStatements
		file.replacedInlineStatements = true
		
		Promise.resolve(file.inlineStatements).bind(file)
			.map (statement)=> @replaceInlineStatements(statement.target) unless statement.kind is 'excluded'
			.then file.replaceInlineStatements



	replaceStatements: (file)->
		return file if file.replacedStatements
		file.replacedStatements = true
		
		Promise.resolve(file.statements).bind(file)
			.map (statement)=> @replaceStatements(statement.target) unless statement.kind is 'excluded'
			.tap ()-> debug "replacing imports/exports #{file.pathDebug}"
			.then file.replaceStatements



	# genSourceMap: (file)->
	# 	Promise.resolve(file.content).bind(file)
	# 		.tap ()-> debug "generating sourcemap #{file.pathDebug}"
	# 		.then ()-> promiseBreak() if not @options.sourceMap
	# 		.then file.genAST
	# 		.then file.genSourceMap
	# 		.then file.adjustSourceMap
	# 		.catch promiseBreak.end
	# 		.return(file)

	
	compile: ()->
		builders = require('./builders')
		generateOpts =
			comments: true
			indent: if @options.indent then '  ' else ''
		
		Promise.bind(@)
			.then @calcImportTree
			.tap ()-> debug "start replacing imports/exports"
			.return @entryFile
			.then @replaceStatements
			.tap ()-> debug "done replacing imports/exports"
			.then ()->
				@statements
					.filter (statement)=> statement.type is 'module' and statement.kind isnt 'excluded' and statement.target isnt @entryFile
					.unique('target')
					.map('target')
					.append(@entryFile, 0)
			
			.tap (files)->
				if files.length is 1 and @entryFile.type isnt 'module' and Object.keys(@requiredGlobals).length is 0
					promiseBreak(parser.generate(@entryFile.ast, generateOpts)+@entryFile.sourceMap.toComment())
			
			.tap ()-> debug "creating bundle AST"
			.then (files)->
				bundle = builders.bundle(@)
				{loader, modules} = builders.loader(@options.target, @options.loaderName)
				@sourceMap = new SourceMapCombiner(@, bundle, loader)
				
				files.forEach (file)=>
					modules.push builders.moduleProp(file, @options.loaderName)
					@sourceMap.add(file)

				bundle.body[0].expression.callee.object.expression.body.body.unshift(loader)
				return bundle

			.tap ()-> debug "generating code from bundle AST"
			.then (ast)-> parser.generate(ast, generateOpts)+@sourceMap.toComment()
			.catch promiseBreak.end
			.then (bundledContent)->
				if not @options.finalTransform.length
					return bundledContent
				else
					config = {ID:'bundle', pkg:@options.pkg, options:{}, content:bundledContent}
					config = helpers.newPathConfig @entryFile.pathAbs, null, config

					Promise.resolve(new File(@, config)).bind(@)
						.tap ()-> debug "applying final transform"
						.then (file)-> file.applyTransforms(file.content, @options.finalTransform, 'final')

			.then (bundledContent)->
				if @entryFile.shebang
					bundledContent = "#{@entryFile.shebang}#{bundledContent}"
				else
					bundledContent
			
			.tap ()-> setTimeout @destroy.bind(@)


	destroy: ()->
		debug "destroying task"
		file.destroy() for file in @files
		@removeAllListeners()
		@files.length = 0
		@statements.length = 0
		@inlineStatements.length = 0
		@files = null
		@statements = null
		@inlineStatements = null
		@imports = null
		@cache = null
		@options = null
		@requiredGlobals = null
		@prevFileInit = null


















### istanbul ignore next ###
extendOptions = (suppliedOptions)->
	options = extend({}, require('./defaults'), suppliedOptions)
	return normalizeOptions(options)


normalizeOptions = (options)->
	options.sourceMap ?= options.debug if options.debug
	options.transform = helpers.normalizeTransforms(options.transform) if options.transform
	options.globalTransform = helpers.normalizeTransforms(options.globalTransform) if options.globalTransform
	options.finalTransform = helpers.normalizeTransforms(options.finalTransform) if options.finalTransform
	options.specific = normalizeSpecificOpts(options.specific) if options.specific
	
	return options


normalizeSpecificOpts = (specificOpts)->
	for p,fileSpecific of specificOpts when fileSpecific.transform
		fileSpecific.transform = helpers.normalizeTransforms(fileSpecific.transform)

	return specificOpts


normalizeEnv = (env, context)-> switch
	when env and typeof env is 'object'
		extend {}, process.env, env

	when typeof env is 'string'
		try
			envFile = fs.read(Path.resolve context, env)
			extend {}, process.env, require('dotenv').parse(envFile)
		catch
			process.env

	else process.env


resetFile = (file)->
	file.processed = null
	file.type = null




module.exports = Task