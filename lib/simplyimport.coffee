require('array-includes').shim()
Promise = require 'bluebird'
fs = Promise.promisifyAll require 'fs-extra'
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
	options = extend({}, defaultOptions, options)
	options.conditions = [].concat(options.conditions) if not Array.isArray(options.conditions)
	state.isMain = true
	state.context ?= if state.isStream then process.cwd() else helpers.getNormalizedDirname(input)
	if state.isStream
		fileContent = Promise.resolve(input)
	else
		fileContent = fs.readFileAsync(PATH.resolve(input), encoding:'utf8')
		state.isCoffee ?= PATH.extname(input).toLowerCase().slice(1) is 'coffee'

	fileContent.then (contents)->
		subjectFile = new File(contents, options, {duplicates:{}}, state)
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
		subjectFile = new File(contents, importOptions, {duplicates:{}}, opts)
		subjectFile.process().then ()->
			subjectFile.collectImports().then ()->

				subjectFile.imports
					.sort (hashA, hashB)->
						subjectFile.orderRefs.findIndex((ref)->ref is hashA) - subjectFile.orderRefs.findIndex((ref)->ref is hashB)
				
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

				






SimplyImport.defaults = defaultOptions
module.exports = SimplyImport