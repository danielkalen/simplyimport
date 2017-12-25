Promise = require 'bluebird'
extend = require 'extend'
parser = require '../external/parser'
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
		@statementNodes = null
		@pendingMods = renames:[], hoist:[]
		@sourceMaps = []
		@offsets = []
		@requiredGlobals = Object.create(null)
		@original = {@pathExt, @content}
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
			@content = @original.content = @content.replace REGEX.shebang, (@shebang)=> return ''

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



	destroy: ()->
		@statements.length = 0
		@inlineStatements.length = 0
		@conditionals.length = 0
		@sourceMaps.length = 0
		@offsets.length = 0
		delete @ID
		delete @ast
		delete @pendingMods
		delete @statements
		delete @inlineStatements
		delete @conditionals
		delete @sourceMaps
		delete @offsets
		delete @requiredGlobals
		delete @parsed
		delete @options
		delete @linesPostTransforms
		delete @linesPostConditionals
		delete @pkgTransform
		delete @task
		for prop of @ when prop.startsWith('content') or prop.startsWith('file')
			delete @[prop] if @hasOwnProperty(prop)


		return
	
	Object.defineProperties @::,
		contentCompiled: get: ()->
			if @has.ast then @contentCompiled = parser.generate(@ast) else @content






extend File::, require './ast'
extend File::, require './hooks'
extend File::, require './checks'
extend File::, require './collect'
extend File::, require './replace'
extend File::, require './compile'
extend File::, require './statements'
extend File::, require './transforms'
module.exports = File