REGEX = require '../constants/regex'
stringHash = require 'string-hash'
parser = require '../external/parser'
helpers = require '../helpers'
debug = require('../debug')('simplyimport:file')

exports.postScans = ()->
	@options.extractDefaults ?= true
	@has.defaultExport ?=
		@type isnt 'inline' and
		REGEX.defaultExport.test(@content) and
		not REGEX.defaultExportDeassign.test(@content)


exports.postTransforms = ()->
	debug "running post-transform functions #{@pathDebug}"
	@timeStart()
	
	if @requiredGlobals.process
		@content = "var process = require('process');\n#{@content}"
		@offsets.push pos:0, length:34
		@has.imports = true
	
	if @requiredGlobals.Buffer
		@content = "var Buffer = require('buffer').Buffer;\n#{@content}"
		@offsets.push pos:0, length:39
		@has.imports = true

	@hashPostTransforms = stringHash(@content)
	@timeEnd()


exports.preCollection = ()-> if @has.ast
	@statementNodes = parser.find @ast, (node)->
		helpers.collectRequires.match(node) or
		helpers.collectImports.match(node) or
		helpers.collectExports.match(node)
	return






