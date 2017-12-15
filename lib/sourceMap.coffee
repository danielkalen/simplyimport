sourceMap = require 'source-map'
sourceMapConvert = require 'convert-source-map'

SourceMap = (opts)->
	map = new sourceMap.SourceMapGenerator(opts)
	map.toComment = toComment
	return map


toComment = ()->
	'\n'+sourceMapConvert
		.fromObject(@toJSON())
		.toComment()


module.exports = SourceMap