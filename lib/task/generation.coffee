Promise = require 'bluebird'
parser = require '../external/parser'
helpers = require '../helpers'
File = require '../file'
debug = require('../debug')('simplyimport:task')

exports.prepareSourceMap = ()-> if @sourceMap
	for statement in @statements.concat(@inlineStatements) when statement.kind isnt 'excluded'
		@sourceMap.setSourceContent statement.target.pathRel, statement.target.original.content
	return

exports.applyFinalTransforms = (bundle)->
	return bundle if not @options.finalTransform.length
	config = {ID:'bundle', pkg:@options.pkg, options:{}, content:bundle}
	config = helpers.newPathConfig @entryFile.pathAbs, null, config

	Promise.resolve(new File(@, config)).bind(@)
		.tap ()-> debug "applying final transform"
		.then (file)-> file.applyTransforms(file.content, @options.finalTransform, 'final')


exports.generate = (ast)->
	parser.generate ast,
		comments: true
		indent: if @options.indent then '  ' else ''
		sourceMap: @sourceMap


exports.attachSourceMap = (bundle)->
	bundle += '\n'+@sourceMap.toComment() if @sourceMap and @options.inlineMap
	return bundle

exports.attachVersions = (bundle)->
	if @options.includeVersions
		versions = "// simplyimport:#{require('../../package.json').version} package:#{@options.pkg.version}"
		bundle = "#{bundle}\n#{versions}"
	
	return bundle

exports.attachShebang = (bundle)->
	bundle = "#{@entryFile.shebang}#{bundle}" if @entryFile.shebang
	return bundle

exports.formatOutput = (code)->
	if @sourceMap and not @options.inlineMap
		return {code, map:@sourceMap.toJSON()}
	return code
