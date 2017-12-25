Promise = require 'bluebird'
stringPos = require 'string-pos'
extend = require 'extend'
helpers = require '../helpers'
REGEX = require '../constants/regex'
EXTENSIONS = require '../constants/extensions'
debug = require('../debug')('simplyimport:file')

exports.collectRequiredGlobals = ()-> if not @has.externalBundle and not EXTENSIONS.static.includes(@pathExt)
	@task.emit('requiredGlobal',@,'global') if REGEX.vars.global.test(@content) and not REGEX.globalCheck.test(@content)
	@task.emit('requiredGlobal',@,'Buffer') if REGEX.vars.buffer.test(@content) and not REGEX.bufferDec.test(@content)
	@task.emit('requiredGlobal',@,'process') if REGEX.vars.process.test(@content) and not REGEX.processDec.test(@content)
	@task.emit('requiredGlobal',@,'__dirname') if REGEX.vars.__dirname.test(@content)
	@task.emit('requiredGlobal',@,'__filename') if REGEX.vars.__filename.test(@content)
	return


exports.collectConditionals = ()-> if REGEX.ifStartStatement.test(@content)
	debug "collecting conditionals #{@pathDebug}"
	@timeStart()
	starts = []
	ends = []

	@content.replace REGEX.ifStartStatement, (e, logic, offset)->
		starts.push [offset, offset+(e.length-logic.length), logic.trim()]
	
	@content.replace REGEX.ifEndStatement, (e, offset)->
		ends.push [offset]

	starts.forEach (start)=>
		end = ends.find (end)-> end[0] > start[0]
		end ?= [@content.length - 1]
		@conditionals.push 
			range: [start[0], end[0]]
			start: stringPos(@original.content, start[0]).line-1
			end: stringPos(@original.content, end[0]).line-1
			match: @task.options.matchAllConditions or helpers.matchConditional(@, start, end)
	
	@timeEnd()



exports.collectForceInlineImports = ()->
	debug "collecting force inline imports #{@pathDebug}"
	@timeStart()
	@content.replace REGEX.inlineImport, (entire, childPath, offset)=>
		statement = helpers.newForceInlineStatement()
		extend statement, resolveStatementTarget(childPath, @)
		statement.source = @
		statement.offset = 0
		statement.range.start = offset
		statement.range.end = offset + entire.length
		statement.range.length = entire.length
		@inlineStatements.push(statement)
	
	@timeEnd()
	return @inlineStatements


exports.collectImports = ()->
	debug "collecting imports #{@pathDebug}"
	collected = []
	@timeStart()
	switch
		when @has.ast and @has.imports
			requires = if @options.skip then [] else helpers.collectRequires(@)
			imports = helpers.collectImports(@)
			statements = imports.concat(requires).sortBy('range.start')

			for statement in statements
				extend statement, resolveStatementTarget(statement.target, @)
				statement.source = @getStatementSource(statement)
				collected.push(statement)



		when @pathExt is 'pug' or @pathExt is 'jade'
			@content.replace REGEX.pugImport, (entireLine, childPath, offset)=>
				statement = helpers.newImportStatement()
				extend statement, resolveStatementTarget(childPath, @)
				statement.range.start = offset
				statement.range.end = offset + entireLine.length
				statement.type = 'inline'
				statement.source = @getStatementSource(statement)
				collected.push(statement)


		when @pathExt is 'sass' or @pathExt is 'scss'
			@content.replace REGEX.cssImport, (entireLine, childPath, offset)=>
				statement = helpers.newImportStatement()
				extend statement, resolveStatementTarget(childPath, @)
				statement.range.start = offset
				statement.range.end = offset + entireLine.length
				statement.type = 'inline'
				statement.source = @getStatementSource(statement)
				collected.push(statement)
	
	@timeEnd()
	@statements.push collected...
	return collected


exports.collectExports = ()->
	debug "collecting exports #{@pathDebug}"
	collected = []
	@timeStart()
	if @has.ast and @has.exports
		statements = helpers.collectExports(@)

		for statement in statements
			statement.source = @getStatementSource(statement)
			statement.target ?= @
			collected.push(statement)
			if statement.kind is 'default' or statement.specifiers?.find(exported:'default')
				@has.defaultExport = true


	@timeEnd()
	@statements.push collected...
	return collected



resolveStatementTarget = (target, file)->
	target = helpers.normalizeTargetPath(target, file, true)
	split = target.split(REGEX.extractDelim)
	return {target:split[0], extract:split[1]}





