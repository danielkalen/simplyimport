require('array-includes').shim()
require('object.entries').shim()
Promise = require 'bluebird'
fs = Promise.promisifyAll require 'fs-extra'
isPlainObject = require 'is-plain-obj'
uniq = require 'uniq'
PATH = require 'path'
extend = require 'extend'
findPkgJson = require 'read-pkg-up'
regEx = require './regex'
helpers = require './helpers'
defaultOptions = require './defaultOptions'
File = require './FileConstructor'
RegExp::test = do ()-> # RegExp::test function patch to reset index after each test
	origTestFn = RegExp::test
	return ()->
		result = origTestFn.apply(@, arguments)
		@lastIndex = 0
		return result




SimplyImport = (input, options, state={})->
	File.instanceCache = {}
	options = extendOptions(options)

	Promise.resolve()
		.then ()->
			state.isMain = true
			state.context ?= if state.isStream then process.cwd() else helpers.getNormalizedDirname(input)
			if state.isStream
				state.suppliedPath = PATH.resolve('main.'+ if state.isCoffee then 'coffee' else 'js')
			else
				state.suppliedPath = input = PATH.resolve(input)
				state.isCoffee ?= PATH.extname(input).toLowerCase().slice(1) is 'coffee'
		
		.then ()->
			### istanbul ignore next ###
			findPkgJson(normalize:false, cwd:state.context)
				.then (result)->
					helpers.resolvePackagePaths(result.pkg, result.path)
					state.pkgFile = pkgFile = result.pkg
					unless state.isStream
						input = pkgFile.browser[input] if typeof pkgFile.browser is 'object' and pkgFile.browser[input]
					delete pkgFile.browserify
				
				.catch ()->

		.then ()-> if state.isStream then input else fs.readFileAsync(input, encoding:'utf8')

		.then (contents)-> new File(contents, options, {}, state)
		.tap (subjectFile)-> subjectFile.process()
		.tap (subjectFile)-> subjectFile.collectImports()
		.then (subjectFile)-> subjectFile.compile()

	



SimplyImport.scanImports = (input, opts={})->
	File.instanceCache = {}
	importOptions = extend({}, defaultOptions, {recursive:false, conditions:['*']})
	opts = extend {}, opts, {isMain:true}

	Promise.resolve()
		.then ()->
			opts.context ?= if opts.isStream then process.cwd() else helpers.getNormalizedDirname(input)
			opts.context = PATH.resolve(opts.context) if not ['/','\\'].includes(opts.context[0])
			opts.context = opts.context.slice(0,-1) if opts.context[opts.context.length-1] is '/'
			if opts.isStream
				opts.suppliedPath = PATH.resolve('main.'+ if opts.isCoffee then 'coffee' else 'js')
			else
				opts.suppliedPath = input = PATH.resolve(input)
				opts.isCoffee ?= PATH.extname(input).toLowerCase().slice(1) is 'coffee'	
		
		.then ()->
			### istanbul ignore next ###
			findPkgJson(normalize:false, cwd:opts.context)
				.then (result)->
					helpers.resolvePackagePaths(result.pkg, result.path)
					opts.pkgFile = pkgFile = result.pkg
					unless opts.isStream
						input = pkgFile.browser[input] if typeof pkgFile.browser is 'object' and pkgFile.browser[input]
					delete pkgFile.browserify
				
				.catch ()->

		.then ()-> if opts.isStream then input else fs.readFileAsync(input, encoding:'utf8')

		.then (contents)-> new File(contents, importOptions, {}, opts)
		.tap (subjectFile)-> subjectFile.process()
		.tap (subjectFile)-> subjectFile.collectImports()
		.then (subjectFile)->
			lineRefs = subjectFile.lineRefs.filter (validRef)-> validRef?

			subjectFile.imports
				.filter (validImport)-> validImport
				.sort (hashA, hashB)-> subjectFile.orderRefs.findIndex((ref)->ref is hashA) - subjectFile.orderRefs.findIndex((ref)->ref is hashB)
				.map (childHash, childIndex)->
					childPath = subjectFile.importRefs[childHash].filePath
					childPath = childPath.replace opts.context+'/', '' if not opts.withContext

					if opts.pathOnly
						return childPath
					else
						importStats = {}
						entireLine = subjectFile.contentLines[lineRefs[childIndex]]
						entireLine.replace regEx.import, (entireLine, priorContent='', spacing='', conditions)->
							importStats = {entireLine, priorContent, spacing, conditions, path:childPath}
						
						return importStats

				

### istanbul ignore next ###
extendOptions = (suppliedOptions)->
	options = extend({}, defaultOptions, suppliedOptions)
	options.conditions = [].concat(options.conditions) if options.conditions and not Array.isArray(options.conditions)
	options.transform = normalizeTransformOpts(options.transform) if options.transform
	options.globalTransform = normalizeTransformOpts(options.globalTransform) if options.globalTransform
	for p,specificOpts of options.fileSpecific
		specificOpts.transform = normalizeTransformOpts(specificOpts.transform) if specificOpts.transform
	
	return options


normalizeTransformOpts = (transform)->
	transform = [].concat(transform) if transform and not Array.isArray(transform)
	if transform.length is 2 and typeof transform[0] is 'string' and isPlainObject(transform[1])
		transform = [transform]

	return transform




SimplyImport.defaults = defaultOptions
module.exports = SimplyImport