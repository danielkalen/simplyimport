Promise = require 'bluebird'
parser = require '../external/parser'
helpers = require '../helpers'
builders = require '../builders'
REGEX = require '../constants/regex'
EXTENSIONS = require '../constants/extensions'
debug = require('../debug')('simplyimport:file')


exports.replaceES6Imports = ()->
	return @content if EXTENSIONS.nonJS.includes(@pathExt)
	hasImports = false
	newContent = @content.replace REGEX.es6import, (original, meta, defaultMember='', members='', childPath)=>
		hasImports = true
		body = "#{childPath}"
		body += ",'#{meta.replace /\s+from\s+/, ''}'" if meta
		replacement = "_$sm(#{body})"
		lenDiff = original.length - replacement.length
		if lenDiff > 0
			padding = ' '.repeat(lenDiff)
			replacement = "_$sm(#{body}#{padding})"
		return replacement

	if hasImports and @pathExt is 'ts'
		newContent = "declare function _$sm(...a: any[]): any;\n#{newContent}"

	return @content = newContent


exports.restoreES6Imports = ()->
	@content = @content.replace REGEX.tempImport, (entire, childPath, meta='')->
		childPath = childPath.slice(1,-1)
		meta = meta.slice(1,-1)
		if not meta then entire else "import #{meta} from '#{childPath}'"



exports.replaceInlineStatements = ()->
	@timeStart()
	debug "replacing force-inline imports #{@pathDebug}"

	split = helpers.splitContentByStatements(@content, @inlineStatements)
	@content = split.reduce (acc, statement)=>
		return acc+statement if typeof statement is 'string'
		replacement = @resolveStatementReplacement(statement)
		index = @inlineStatements.indexOf(statement)
		leadingStatements = @inlineStatements.slice(index)
		leadingStatements.forEach (statement)->
			statement.offset += replacement.length - statement.range.length
		# newRange = helpers.newReplacementRange(statement.range, replacement)
		# replacementRange = @addRangeOffset 'inlines', newRange
		# replacementRange.source = statement.target
		# range = @offsetRange(statement.range, ['inline-forced'], rangeGroup)
		# newRange = helpers.newReplacementRange(range, replacement)
		# @sourceMap.addRange {
		# 	from: {start:0, end:statement.target.original.content.length}
		# 	to: newRange
		# 	file: statement.target
		# 	offset: 0
		# 	name: "#{type}:#{index+1}"
		# 	content
		# }
		return acc+replacement

	@timeEnd()
	return


exports.replaceStatements = ()->
	@timeStart()
	debug "replacing imports/exports #{@pathDebug}"
	type = 'inline-forced' if not @has.ast
	for statement in @statements
		statement.replacement = @resolveStatementReplacement(statement, type)

	@timeEnd()
	return



exports.resolveStatementReplacement = (statement, type)->
	type ?= if statement.statementType is 'export' then 'export' else statement.type

	switch type
		when 'inline-forced'
			return '' if statement.kind is 'excluded'
			targetContent = if statement.extract then statement.target.extract(statement.extract) else statement.target.contentCompiled
			targetContent = helpers.prepareMultilineReplacement(@content, targetContent, statement.range)
			targetContent = '{}' if not targetContent

			if EXTENSIONS.compat.includes(statement.target.pathExt)
				lastChar = @content[statement.range.end]
				targetContent = "(#{targetContent})" if lastChar is '.' or lastChar is '('

			return targetContent
		
		when 'inline'
			return builders.inlineImport(statement)

		when 'module' # regular import
			return builders.import(statement)

		when 'export'
			return builders.export(statement)










