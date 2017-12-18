Promise = require 'bluebird'
promiseBreak = require 'promise-break'
stringPos = require 'string-pos'
parser = require '../external/parser'
helpers = require '../helpers'
REGEX = require '../constants/regex'
EXTENSIONS = require '../constants/extensions'
GLOBALS = require '../constants/globals'
debug = require('../debug')('simplyimport:file')

exports.collectRequiredGlobals = ()-> if not @has.externalBundle and not EXTENSIONS.static.includes(@pathExt)
	@task.emit('requiredGlobal',@,'global') if REGEX.vars.global.test(@content) and not REGEX.globalCheck.test(@content)
	@task.emit('requiredGlobal',@,'Buffer') if REGEX.vars.buffer.test(@content) and not REGEX.bufferDec.test(@content)
	@task.emit('requiredGlobal',@,'process') if REGEX.vars.process.test(@content) and not REGEX.processDec.test(@content)
	@task.emit('requiredGlobal',@,'__dirname') if REGEX.vars.__dirname.test(@content)
	@task.emit('requiredGlobal',@,'__filename') if REGEX.vars.__filename.test(@content)
	return


exports.collectConditionals = ()->
	Promise.bind(@)
		.tap ()-> debug "collecting conditionals #{@pathDebug}"
		.tap @timeStart
		.then ()->
			starts = []
			ends = []

			@content.replace REGEX.ifStartStatement, (e, logic, offset)=>
				starts.push [offset, offset+(e.length-logic.length), logic.trim()]
			
			@content.replace REGEX.ifEndStatement, (e, offset)=>
				ends.push [offset]

			starts.forEach (start)=>
				end = ends.find (end)-> end[0] > start[0]
				end ?= [@content.length - 1]
				@conditionals.push 
					range: [start[0], end[0]]
					start: stringPos(@original.content, start[0]).line-1
					end: stringPos(@original.content, end[0]).line-1
					match: @task.options.matchAllConditions or do ()=>
						file = @
						jsString = ''
						tokens = parser.tokenize(start[2])
						env = @task.options.env
						BUNDLE_TARGET = @task.options.target

						helpers.walkTokens tokens, @original.content, null, (token)->
							switch token.type.label
								when 'name'
									if @_prev?.value is '.' or GLOBALS.includes(token.value)
										jsString += token.value
									else if token.value is 'BUNDLE_TARGET'
										jsString += " '#{BUNDLE_TARGET}'"
									else
										value = env[token.value]
										jsString += " env['#{token.value}']"

								when 'string'
									jsString += "'#{token.value}'"

								when 'regexp'
									jsString += "#{token.value.value}"

								when '=','==/!=','||','|','&&','&'
									jsString += ' ' + switch token.value
										when '=','==','===' then '=='
										when '!=','!==' then '!='
										when '||','|' then '||'
										when '&&','&' then '&&'
										else token.value
								else
									if token.type.keyword
										jsString += " #{token.value} "
									else
										jsString += token.value

								# else file.task.emit 'ConditionalError', file, token.start+start[1], token.end+start[1]
						try
							return require('vm').runInNewContext(jsString, {env})
						catch err
							file.task.emit 'ConditionalError', file, err
							return false

		.tap ()-> promiseBreak() if not @conditionals.length
		.then ()->
			linesToRemove = []
			@conditionals.forEach (conditional)=>
				if conditional.match
					linesToRemove.push conditional.start
					linesToRemove.push conditional.end
				else
					linesToRemove.push [conditional.start..conditional.end]...
				return
			
			return new ()-> @[index]=true for index in linesToRemove; @

		.then (linesToRemove)->
			outputLines = []
			@content.split('\n').forEach (line, index)=>
				if not linesToRemove[index]
					outputLines.push(line)
				else
					index = stringPos.toIndex(@original.content,{line:index+1, column:0})

			return outputLines.join('\n')

		.then (result)-> @content = result
		.catch promiseBreak.end
		.tap @timeEnd



exports.collectForceInlineImports = ()->
	debug "collecting force inline imports #{@pathDebug}"
	@timeStart()
	@content.replace REGEX.inlineImport, (entire, childPath, offset)=>
		statement = helpers.newImportStatement()
		statement.source = @
		statement.target = helpers.normalizeTargetPath(childPath, @, true)
		targetSplit = statement.target.split(REGEX.extractDelim)
		statement.target = targetSplit[0]
		statement.extract = targetSplit[1]
		statement.offset = 0
		statement.range.start = offset
		statement.range.end = offset + entire.length
		statement.range.length = entire.length
		statement.type = 'inline-forced'
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
				statement.target = helpers.normalizeTargetPath(statement.target, @)
				targetSplit = statement.target.split(REGEX.extractDelim)
				statement.target = targetSplit[0]
				statement.extract = targetSplit[1]
				statement.source = @getStatementSource(statement)
				collected.push(statement)



		when @pathExt is 'pug' or @pathExt is 'jade'
			@content.replace REGEX.pugImport, (entireLine, childPath, offset)=>
				statement = helpers.newImportStatement()
				statement.target = helpers.normalizeTargetPath(childPath, @, true)
				statement.range.start = offset
				statement.range.end = offset + entireLine.length
				statement.type = 'inline'
				statement.source = @getStatementSource(statement)
				collected.push(statement)


		when @pathExt is 'sass' or @pathExt is 'scss'
			@content.replace REGEX.cssImport, (entireLine, childPath, offset)=>
				statement = helpers.newImportStatement()
				statement.target = helpers.normalizeTargetPath(childPath, @, true)
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







