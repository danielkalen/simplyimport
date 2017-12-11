stringHash = require 'string-hash'
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
	debug "checking 3rd party bundle status #{@pathDebug}"
	@timeStart()
	### istanbul ignore next ###
	@isThirdPartyBundle =
		@content.includes('.code="MODULE_NOT_FOUND"') or
		@content.includes('__webpack_require__') or
		@content.includes('System.register') or 
		@content.includes("' has not been defined'") or
		REGEX.moduleCheck.test(@content) or
		REGEX.defineCheck.test(@content) or
		REGEX.requireCheck.test(@content)

	@has.requires = REGEX.commonImportReal.test(@content)
	@has.exports = REGEX.commonExport.test(@content) or REGEX.es6export.test(@content)
	@has.imports = @has.requires or REGEX.es6import.test(@content) or REGEX.tempImport.test(@content)
	@has.ownRequireSystem =
		REGEX.requireDec.test(@content) or
		REGEX.requireArg.test(@content) and @has.requires

	@isThirdPartyBundle = @isThirdPartyBundle or @has.ownRequireSystem
	@options.skip ?= @isThirdPartyBundle and @has.ownRequireSystem and @has.requires
	@timeEnd()
	return


exports.determineType = ()->
	@type = switch
		when @type is 'inline-forced' then @type
		when @pathExtOriginal is 'ts' then 'module'
		when not @has.exports then 'inline'
		else 'module'

	@isDataType = true if EXTENSIONS.data.includes(@pathExt)



exports.postScans = ()->
	@options.extractDefaults ?= true
	@has.defaultExport ?=
		@type isnt 'inline' and
		REGEX.defaultExport.test(@content) and
		not REGEX.defaultExportDeassign.test(@content)


exports.postTransforms = ()->
	debug "running post-transform functions #{@pathDebug}"
	@timeStart()
	@content = @sourceMap.update(@content)
	
	if @requiredGlobals.process
		@content = "var process = require('process');\n#{@content}"
		@sourceMap.addNullRange(0, 34, true)
		@has.imports = true
	
	if @requiredGlobals.Buffer
		@content = "var Buffer = require('buffer').Buffer;\n#{@content}"
		@sourceMap.addNullRange(0, 39, true)
		@has.imports = true

	@hashPostTransforms = stringHash(@content)
	@timeEnd()








