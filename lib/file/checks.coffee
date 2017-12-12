parser = require '../external/parser'
REGEX = require '../constants/regex'
EXTENSIONS = require '../constants/extensions'
debug = require('../debug')('simplyimport:file')


exports.checkSyntaxErrors = ((content)->
	debug "checking for syntax errors #{@pathDebug}"
	if @pathExt is 'js'
		@timeStart()
		content = content.replace REGEX.es6import, "importPlaceholder()"
		
		if err = parser.check(content, @pathAbs)
			@task.emit 'SyntaxError', @, err

		@timeEnd()
).memoize()


exports.runChecks = ()->
	debug "running checks #{@pathDebug}"
	@timeStart()
	@detectStatements()
	@detectExternalBundle()
	@options.skip ?= @has.externalBundle and @has.ownRequireSystem and @has.requires
	@timeEnd()
	return


exports.detectStatements = ()->
	@has.requires = REGEX.commonImportReal.test(@content)
	@has.exports = REGEX.commonExport.test(@content) or REGEX.es6export.test(@content)
	@has.imports = @has.requires or REGEX.es6import.test(@content) or REGEX.tempImport.test(@content)
	return


exports.detectExternalBundle = ()->
	### istanbul ignore next ###
	@has.externalBundle =
		@content.includes('.code="MODULE_NOT_FOUND"') or
		@content.includes('__webpack_require__') or
		@content.includes('System.register') or 
		@content.includes("' has not been defined'") or
		REGEX.moduleCheck.test(@content) or
		REGEX.defineCheck.test(@content) or
		REGEX.requireCheck.test(@content)
	
	@has.ownRequireSystem =
		REGEX.requireDec.test(@content) or
		REGEX.requireArg.test(@content) and @has.requires

	@has.externalBundle = @has.externalBundle or @has.ownRequireSystem
	return


exports.determineType = ()->
	@type = switch
		when @type is 'inline-forced' then @type
		when @original.pathExt is 'ts' then 'module'
		when not @has.exports then 'inline'
		else 'module'

	@isDataType = true if EXTENSIONS.data.includes(@pathExt)







