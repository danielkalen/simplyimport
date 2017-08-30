helpers = require './helpers'
sourceMap = require 'source-map'
sourceMapConvert = require 'convert-source-map'

class SourceMap
	constructor: (@file)->
		@disabled = not @file.task.options.sourceMap
		unless @disabled
			@lastContent = @file.content
			@initialMap = @extractFromContent()
			if @initialMap
				@map = sourceMap.SourceMapGenerator.fromSource(new sourceMap.SourceMapConsumer @initialMap)
				@file.content = sourceMapConvert.removeComments(@file.content)
			else
				@map = new sourceMap.SourceMapGenerator(file:@file.pathRel)

			@map.setSourceContent @file.pathRel, @file.contentOriginal


	extractFromContent: (content=@file.content)-> unless @disabled or @lastContent is content
		@lastContent = content
		sourceMapConvert.fromSource(content)?.sourcemap


	update: (content)->
		unless @disabled
			newSourceMap = @extractFromContent(content)
			
			if newSourceMap
				@map.applySourceMap(new sourceMap.SourceMapConsumer newSourceMap)
				content = sourceMapConvert.removeComments(content)
		
		return content


	add: ({file=@file, from, to, offset, name, content=file.content})-> unless @disabled
		@map.addMapping
			source: file.pathRel
			original: if Object.isNumber(from) then getLocation(file, from) else from
			generated: if Object.isNumber(to) then getLocation(@file, to, content, offset) else to
			name: name

		if file isnt @file
			@map.setSourceContent file.pathRel, file.contentOriginal


	addNull: (mapping)-> unless @disabled
		@map.addMapping
			source: @file.pathRel
			original: line:1, column:0
			generated: if Object.isNumber(mapping) then getLocation(@file, mapping) else mapping


	addRange: ({file=@file, from, to, offset, name, content=file.content})-> unless @disabled
		# @offset({from, to, content}) if offset
		@add {file, from:from.start, to:to.start, name, offset, content}
		@add {file, from:from.end, to:to.end, name, offset, content}


	addNullRange: (from, to, offsetAbove)-> unless @disabled
		@offset({from, to}) if offsetAbove
		@addNull(from)
		@addNull(to)


	offset: ({from, to, content=@file.content})->
		lines = helpers.lines(content)
		offset = lines.locationForIndex(to)
	
		for mapping in @map._mappings._array
			mappingIndex = lines.indexForLocation(line:mapping.generatedLine-1, column:mapping.generatedColumn)
			continue unless to <= mappingIndex
			mapping.generatedLine += offset.line
			mapping.generatedColumn += offset.column


	toComment: ()->
		if @disabled
			return ''
		else
			'\n'+sourceMapConvert
				.fromObject(@map.toJSON())
				.toComment()


getLocation = (file, index, content, offset=0)->
	if Object.isNumber(index)
		lines = if content? then helpers.lines(content) else file.linesOriginal
		loc = lines.locationForIndex(index)
		return {line:loc.line+1+offset, column:loc.column}
	else
		return {line:index.line+1+offset, column:index.column}




module.exports = SourceMap