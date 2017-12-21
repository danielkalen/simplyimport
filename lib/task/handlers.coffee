Promise = require 'bluebird'
chalk = require 'chalk'
formatError = require '../external/formatError'
helpers = require '../helpers'
LABELS = require '../constants/consoleLabels'
debug = require('../debug')('simplyimport:task')
{EMPTY_STUB} = require('../constants')


exports.attachListeners = ()->
	@.on 'requiredGlobal', (file, varName)=>
		if varName isnt 'global' #if varName.startsWith('__')
			file.requiredGlobals[varName] = true
		else
			@requiredGlobals[varName] = true

	@.on 'missingImport', (file, target, posStart, posEnd)->
		annotation = helpers.annotateErrLocation(file, posStart, posEnd)
		if @options.ignoreMissing
			console.warn "#{LABELS.warn} cannot find '#{chalk.yellow target}'", annotation unless @options.ignoreErrors
		else
			@throw formatError "#{LABELS.error} cannot find '#{chalk.yellow target}'", helpers.blankError(annotation), true

	@.on 'missingEntry', ()=>
		throw formatError "#{LABELS.error} cannot find '#{chalk.yellow @options.file}'", helpers.blankError()
	
	@.on 'ASTParseError', (file, err)=> unless @options.ignoreSyntaxErrors
		err.message += helpers.annotateErrLocation(file, err.pos)
		@throw formatError "#{LABELS.error} Failed to parse #{file.pathDebug}", err, true
	
	@.on 'DataParseError', (file, err)=>
		if pos = err.message.match(/at position (\d+)/)?[1]
			err.message += helpers.annotateErrLocation(file, pos)
		@throw formatError "#{LABELS.error} Failed to parse #{file.pathDebug}", err, true
	
	@.on 'ExtractError', (file, err)=>
		@throw formatError "#{LABELS.error} Extraction error in #{file.pathDebug}", err
			
	@.on 'ConditionalError', (file, err, posStart, posEnd)=>
		err ?= helpers.blankError helpers.annotateErrLocation(file, posStart, posEnd)
		@throw formatError "#{LABELS.error} Invalid conditional syntax in #{file.pathDebug}", err
	
	@.on 'TransformError', (file, err, transformer)=>
		name = chalk.dim transformer.name or String transformer.fn
		@throw formatError "#{LABELS.error} Error while applying transform #{name} to #{file.pathDebug}", err
	
	@.on 'GeneralError', (file, err)=>
		throw err if err.message.startsWith(LABELS.error)
		throw formatError "#{LABELS.error} Error while processing #{file.pathDebug}", err


exports.handleExcludedFile = (file, statement)->
	file.excluded = true


exports.handleIgnoredFile = (file, statement)->
	Promise.bind(@)
		.then ()-> @initFile EMPTY_STUB, file, false, false
		.then (emptyFile)->
			statement.target = emptyFile
			statement.extract = undefined


exports.handleMissingFile = (file, statement)->
	@emit 'missingImport', file, statement.target, statement.range.start, statement.range.end

	Promise.bind(@)
		.then ()-> @initFile EMPTY_STUB, file, false, false
		.then (emptyFile)->
			statement.target = emptyFile
			statement.extract = undefined


