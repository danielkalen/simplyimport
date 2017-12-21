Promise = require 'bluebird'
Path = require '../helpers/path'
fs = require 'fs-jetpack'
extend = require 'extend'
helpers = require '../helpers'
SourceMap = require '../sourceMap'
debug = require('../debug')('simplyimport:task')
{EMPTY_STUB} = require('../constants')


class Task extends require('events')
	constructor: (options)->
		super
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
		@options.context ?= if @options.file then helpers.getNormalizedDirname(@options.file) else process.cwd()
		if @options.file
			@options.ext = Path.extname(@options.file).replace('.','') or 'js'
			@options.suppliedPath = Path.resolve(@options.file)
		else
			@options.ext ?= 'js'
			@options.suppliedPath = Path.resolve("entry.#{@options.ext}")

		@sourceMap = if @options.sourceMap then SourceMap(file:'bundle.js') else null
		@attachListeners()
		debug "new task created"



	throw: (err)->
		throw err unless @options.ignoreErrors


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




extend Task::, require './init'
extend Task::, require './process'
extend Task::, require './handlers'
extend Task::, require './statements'
extend Task::, require './generation'
module.exports = Task