# SourceMap = require './sourceMap'
helpers = require './helpers'
combine = require 'combine-source-map'
{OFFSETS} = require './builders/strings'

class SourceMapCombiner
	constructor: (@task, bundle, loader)->
		@disabled = !@task.options.sourceMap
		unless @disabled
			@offset = line:2+OFFSETS.bundle+OFFSETS.loader
			@map = combine.create('bundle.js')

	add: (file)-> unless @disabled
		# console.log require('combine-source-map/lib/mappings-from-map') (require('convert-source-map').fromSource(file.sourceMap.toComment())).toObject()
		content = "#{file.content}#{file.sourceMap.toComment()}"
		@map.addFile({source:content, sourceFile:file.pathRel}, @offset)
		@offset.line += helpers.lineCount(content)+OFFSETS.module

	toComment: ()->
		if @disabled
			return ''
		else
			return '\n'+@map.comment()








module.exports = SourceMapCombiner