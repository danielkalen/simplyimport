Promise = require 'bluebird'
extend = require 'extend'
SourceMap = require '../sourceMap'
helpers = require '../helpers'
REGEX = require '../constants/regex'
GLOBALS = require '../constants/globals'
debug = require('../debug')('simplyimport:file')


class File	
	constructor: (@task, state)->
		extend(@, state)
		@options.transform ?= []
		@IDstr = JSON.stringify(@ID)
		@ast = @parsed = null
		@time = 0
		@has = Object.create(null)
		@statements = []
		@inlineStatements = []
		@conditionals = []
		@pendingMods = renames:[], hoist:[]
		@requiredGlobals = Object.create(null)
		@pathExtOriginal = @pathExt
		@contentOriginal = @content
		@linesOriginal = helpers.lines(@content)
		@sourceMap = new SourceMap(@)
		@options.placeholder = helpers.resolvePlaceholders(@)
		@pkgEntry = helpers.resolvePackageEntry(@pkg)
		@pkgTransform = @pkg.browserify?.transform
		@pkgTransform = helpers.normalizeTransforms(@pkgTransform) if @pkgTransform
		@pkgTransform = do ()=>
			transforms = @pkg.simplyimport?.transform if @isExternal
			transforms ?= @pkg.browserify?.transform
			if transforms
				helpers.normalizeTransforms(transforms)

		if REGEX.shebang.test(@content)
			@content = @contentOriginal = @content.replace REGEX.shebang, (@shebang)=> return ''

		return @task.cache[@pathAbs] = @


	timeStart: ()->
		@timeEnd() if @startTime
		@startTime = Date.now()
	

	timeEnd: ()->
		@time += Date.now() - (@startTime or Date.now())
		@startTime = null


	setContent: (content)->
		@content = content
		if @ast?.content?
			@ast.content = content

	saveContent: (milestone, content)->
		content = @sourceMap.update(content)
		if arguments.length is 1
			content = arguments[0]
		else
			@[milestone] = content

		@content = content



	destroy: ()->
		@statements.length = 0
		@inlineStatements.length = 0
		@conditionals.length = 0
		delete @ID
		delete @ast
		delete @pendingMods
		delete @statements
		delete @inlineStatements
		delete @conditionals
		delete @requiredGlobals
		delete @parsed
		delete @options
		delete @linesPostTransforms
		delete @linesPostConditionals
		delete @linesOriginal
		delete @pkgTransform
		delete @task
		for prop of @ when prop.startsWith('content') or prop.startsWith('file')
			delete @[prop] if @hasOwnProperty(prop)


		return






extend File::, require './ast'
extend File::, require './hooks'
extend File::, require './checks'
extend File::, require './collect'
extend File::, require './replace'
extend File::, require './statements'
extend File::, require './transforms'
module.exports = File