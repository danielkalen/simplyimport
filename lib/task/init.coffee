Promise = require 'bluebird'
promiseBreak = require 'promise-break'
Path = require '../helpers/path'
stringHash = require 'string-hash'
fs = require 'fs-jetpack'
chalk = require 'chalk'
extend = require 'extend'
helpers = require '../helpers'
File = require '../file'
BUILTINS = require('../constants/coreShims').builtins
debug = require('../debug')('simplyimport:task')

exports.initEntryFile = ()->
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
		
			@options.env = getEnv(@options.env, @options.pkg.dirPath) # we do this here to allow loading of option from package.json
			promiseBreak(@options.src) if @options.src
		
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


exports.initFile = (input, importer, isForceInlined, prev=@prevFileInit)->
	suppliedPath = input
	pkg = null

	@prevFileInit = thisFileInit = 
	Promise.resolve(prev).bind(@)
		.catch ()-> null # If prev was rejected with ignored/missing error
		.tap ()-> debug "start file init for #{chalk.dim input}"
		.then ()-> helpers.resolveModulePath(input, importer, @options.target)
		.then (module)->
			pkg = module.pkg
			return module.file

		.then (input)-> helpers.resolveFilePath(input, importer, @entryFile.context, suppliedPath)
		.tap (config)->
			if @cache[config.pathAbs]
				debug "using cached file for #{config.pathDebug}"
				promiseBreak(@cache[config.pathAbs])
			else
				debug "creating new file for #{config.pathDebug}"
				@cache[config.pathAbs] = thisFileInit
				return

		.tap (config)->
			config.pkg = pkg or {}
			config.isExternal = config.pkg isnt @entryFile.pkg
			config.isExternalEntry = config.isExternal and config.pkg isnt importer.pkg

			throw new Error('excluded') if helpers.matchGlob(config, @options.excludeFile) or config.isExternal and not @options.bundleExternal or @options.target is 'node' and BUILTINS.includes(suppliedPath)
			throw new Error('ignored') if helpers.matchGlob(config, @options.ignoreFile)
			throw new Error('missing') if not fs.exists(config.pathAbs)

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




getEnv = (env, context)-> switch
	when env and typeof env is 'object'
		extend {}, process.env, env

	when typeof env is 'string'
		path = Path.resolve(context, env)
		return require('mountenv').getAll(Path.dirname(path), Path.basename(path))

	else process.env



normalizeOptions = (options)->
	options.sourceMap ?= options.debug# if options.debug
	options.transform = helpers.normalizeTransforms(options.transform) if options.transform
	options.globalTransform = helpers.normalizeTransforms(options.globalTransform) if options.globalTransform
	options.finalTransform = helpers.normalizeTransforms(options.finalTransform) if options.finalTransform
	options.specific = normalizeSpecificOpts(options.specific) if options.specific
	
	return options


normalizeSpecificOpts = (specificOpts)->
	for p,fileSpecific of specificOpts when fileSpecific.transform
		fileSpecific.transform = helpers.normalizeTransforms(fileSpecific.transform)

	return specificOpts


