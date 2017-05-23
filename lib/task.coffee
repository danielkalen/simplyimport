Promise = require 'bluebird'
promiseBreak = require 'p-break'
PATH = require 'path'
md5 = require 'md5'
fs = require 'fs-jetpack'
chalk = require 'chalk'
extend = require 'extend'
findPkgJson = require 'read-pkg-up'
helpers = require './helpers'
File = require './file'
labels = require './consoleLabels'
ALLOWED_EXTENSIONS = ['js','ts','coffee','sass','scss','css','html','jade','pug']

class Task extends require('events')
	constructor: (options, @entryInput, @isScanOnly)->
		@currentID = -1
		@importStatements = []
		@imports = Object.create(null)
		@importRefs = Object.create(null)
		@cache = Object.create(null)
		@requiredGlobals = {}
		
		@options = extendOptions(options)
		@options.context ?= if @options.isStream then process.cwd() else helpers.getNormalizedDirname(@entryInput)
		if @options.isStream
			@options.suppliedPath = PATH.resolve('main.'+ if @options.isCoffee then 'coffee' else 'js')
		else
			@options.suppliedPath = @entryInput = PATH.resolve(@entryInput)
			@options.isCoffee ?= PATH.extname(@entryInput).toLowerCase() is '.coffee'
		
		super
		@.on 'requiredGlobal', (varName)=> @requiredGlobals[varName] = true
		@.on 'astParseError', (file, err)=> unless @isScanOnly
			console.warn "#{labels.warn} Failed to parse #{chalk.dim file.filePathSimple}", require('stack-filter')(err.stack)


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
				if extname and ALLOWED_EXTENSIONS.includes(extname)
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
					exactMatch = inputPathMatches.find (targetPath)-> targetPath is params.base
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
				contextRel = context.replace(@entryFile.context, '')
				filePathSimple = helpers.simplifyPath(filePath)
				filePathRel = filePath.replace(@entryFile.context, '')
				fileExt = PATH.extname(filePath).toLowerCase().slice(1)
				suppliedPath = input
				return {filePath, filePathSimple, filePathRel, context, contextRel, suppliedPath, fileExt}


	initEntryFile: ()->
		Promise.bind(@)
			.then ()-> promiseBreak(@entryInput) if @options.isStream
			.then ()-> fs.readAsync(@entryInput)
			.catch promiseBreak.end
			.then (content)->
				@entryFile = new File @, {
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
				}


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

			.catch promiseBreak.end



	processFile: (file)-> unless file.processed
		file.processed = true
		Promise.bind(file)
			.then file.checkIfIsThirdPartyBundle
			.then file.collectRequiredGlobals
			.then file.collectIgnoreRanges
			.then file.determineType
			.then file.findCustomImports
			.then file.findES6Imports
			.then file.customImportsToCommonJS
			.then file.ES6ImportsToCommonJS
			.then file.applyAllTransforms
			.then file.attemptASTGen
			.return(file)


	scanImports: (file, depth=Infinity, currentDepth=0)->
		file.scanned = true
		Promise.bind(@)
			.then ()-> file.collectImports()
			.tap (imports)-> @importStatements.push(imports...)
			.map (importStatement)->
				Promise.bind(@)
					.then ()-> @initFile(importStatement.target, file)
					.then (childFile)-> importStatement.target = childFile
					.return(importStatement)

			.tap ()-> promiseBreak(@importStatements) if ++currentDepth >= depth
			.filter (importStatement)-> not importStatement.target.scanned
			.map (importStatement)-> @scanImports(importStatement.target)
			.catch promiseBreak.end
			.return(@importStatements)



	calcImportTree: ()->
		Promise.bind(@)
			.then ()->
				for statement in @importStatements
					@imports[statement.target.hash] ?= []
					@imports[statement.target.hash].push statement
				return

			.then ()->
				for hash,importStatement of @imports
					@imports[]
				return





















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