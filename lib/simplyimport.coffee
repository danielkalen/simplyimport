require('array-includes').shim()
require('object.entries').shim()
Promise = require 'bluebird'
fs = Promise.promisifyAll require 'fs-extra'
isPlainObject = require 'is-plain-obj'
uniq = require 'uniq'
PATH = require 'path'
extend = require 'extend'
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
	state.isMain = true
	state.context ?= if state.isStream then process.cwd() else helpers.getNormalizedDirname(input)
	if state.isStream
		state.suppliedPath = PATH.resolve('main.'+ if state.isCoffee then 'coffee' else 'js')
		fileContent = Promise.resolve(input)
	else
		state.suppliedPath = input = PATH.resolve(input)
		fileContent = fs.readFileAsync(input, encoding:'utf8')
		state.isCoffee ?= PATH.extname(input).toLowerCase().slice(1) is 'coffee'

	fileContent.then (contents)->
		subjectFile = new File(contents, options, {}, state)
		subjectFile.process().then ()->
			subjectFile.collectImports().then ()->
				return subjectFile.compile()

	



SimplyImport.scanImports = (input, opts={})->
	File.instanceCache = {}
	importOptions = extend({}, defaultOptions, {recursive:false})
	opts = extend {}, opts, {isMain:true}
	opts.context ?= if opts.isStream then process.cwd() else helpers.getNormalizedDirname(input)
	opts.context = PATH.resolve(opts.context) if not ['/','\\'].includes(opts.context[0])
	opts.context = opts.context.slice(0,-1) if opts.context.slice(-1)[0] is '/'
	
	if opts.isStream
		fileContent = Promise.resolve(input)
	else
		fileContent = fs.readFileAsync(PATH.resolve(input), encoding:'utf8')
		opts.isCoffee ?= PATH.extname(input).toLowerCase().slice(1) is 'coffee'
	
	fileContent.then (contents)->
		subjectFile = new File(contents, importOptions, {}, opts)
		subjectFile.process().then ()->
			subjectFile.collectImports().then ()->

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
							entireLine = subjectFile.contentLines[subjectFile.lineRefs[childIndex]]
							entireLine.replace regEx.import, (entireLine, priorContent='', spacing='', conditions)->
								importStats = {entireLine, priorContent, spacing, conditions, path:childPath}
							
							return importStats

				


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