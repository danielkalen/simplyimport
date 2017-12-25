Promise = require 'bluebird'
parser = require '../external/parser'
helpers = require '../helpers'
builders = require '../builders'
REGEX = require '../constants/regex'
EXTENSIONS = require '../constants/extensions'
debug = require('../debug')('simplyimport:file')
LOC_FIRST = {line:1, column:0}


exports.replaceConditionals = ()-> if @conditionals.length
	@timeStart()
	linesToRemove = Object.create(null)
	outputLines = []
	
	for conditional in @conditionals
		if conditional.match
			linesToRemove[conditional.start] = 1
			linesToRemove[conditional.end] = 1
		else
			for index in [conditional.start..conditional.end]
				linesToRemove[index] = 1
	
	for line,index in @content.split('\n')
		outputLines.push(line) unless linesToRemove[index]

	@content = @original.content = outputLines.join('\n')
	@timeEnd()
	return


exports.replaceES6Imports = ()->
	return @content if EXTENSIONS.nonJS.includes(@pathExt)
	newContent = @content.replace REGEX.es6import, (original, meta, defaultMember='', members='', childPath)=>
		@has.imports = true
		body = "#{childPath}"
		body += ",'#{meta.replace /\s+from\s+/, ''}'" if meta
		replacement = "_$sm(#{body})"
		lenDiff = original.length - replacement.length
		if lenDiff > 0
			padding = ' '.repeat(lenDiff)
			replacement = "_$sm(#{body}#{padding})"
		return replacement

	if @has.imports and @pathExt is 'ts'
		newContent = "declare function _$sm(...a: any[]): any;\n#{newContent}"

	return @content = newContent


exports.restoreES6Imports = ()-> if @has.imports
	@content = @content.replace REGEX.tempImport, (entire, childPath, meta='')->
		childPath = childPath.slice(1,-1)
		meta = meta.slice(1,-1)
		if not meta then entire else "import #{meta} from '#{childPath}'"



exports.replaceInlineStatements = ()-> if @inlineStatements.length
	@timeStart()
	debug "replacing force-inline imports #{@pathDebug}"

	output = ''
	change = 0
	chunks = helpers.splitContentByStatements(@content, @inlineStatements)

	for chunk in chunks
		if typeof chunk isnt 'string'
			{range, rangeNew} = statement = chunk
			statement.replacement = replacement = @resolveStatementReplacement(statement)
			rangeNew.diff = replacement.length - range.length
			rangeNew.start = range.start+change
			rangeNew.end = rangeNew.start+replacement.length
			change += rangeNew.diff
			chunk = replacement

		output += chunk

	@contentPostInlinement = @content = output
	@timeEnd()
	return



exports.resolveReplacements = ()-> if @statements.length
	@timeStart()
	debug "resolving replacements #{@pathDebug}"
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










