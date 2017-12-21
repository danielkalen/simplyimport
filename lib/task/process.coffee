Promise = require 'bluebird'
promiseBreak = require 'promise-break'
helpers = require '../helpers'
REGEX = require '../constants/regex'
debug = require('../debug')('simplyimport:task')
{EMPTY_STUB} = require('../constants')


exports.processFile = (file)-> if file.processed then file.processed else
	file.processed =
	Promise.bind(file)
		.tap ()-> debug "processing #{file.pathDebug}"
		.then file.collectConditionals
		.then ()=> @scanInlineStatements(file)
		.then ()=> @replaceInlineStatements(file)
		.tap ()-> promiseBreak() if file.type is 'inline-forced'
		.then file.replaceES6Imports
		.then file.applyAllTransforms
		.then file.replaceES6Imports
		.then file.restoreES6Imports
		.then file.runChecks
		.then(file.collectRequiredGlobals unless @options.target is 'node')
		.then file.postTransforms
		.then file.determineType
		.then file.parse
		.catch promiseBreak.end
		.tap ()-> debug "done processing #{file.pathDebug}"
		.return(file)




exports.calcImportTree = ()->
	Promise.bind(@)
		.tap ()-> debug "start calculating import tree"
		.then ()-> @imports = @statements.concat(@inlineStatements).groupBy('target.pathAbs')

		.then ()-> Object.values(@imports)
		
		.map (statements)-> # determine statement types
			statements = statements.filter (statement)-> statement.kind isnt 'excluded'

			if statements.length > 1 or statements.some(helpers.isMixedExtStatement) or statements.some(helpers.isRecursiveImport)
				targetType = 'module'

			Promise.map statements, (statement)=>
				statement.type = targetType or statement.target.type

				if statement.extract and statement.target.pathExt isnt 'json'
					@emit 'ExtractError', statement.target, new Error "invalid attempt to extract data from a non-data file type"

				requiresModification = 
					statement.type is 'module' and
					statement.target.type is 'inline' and
					not statement.target.becameModule and
					not statement.target.path isnt EMPTY_STUB
				
				if requiresModification
					statement.target.exportLastExpression()
					statement.target.becameModule = true

		
		.then ()-> # perform data extractions
			dataFiles = @files.filter (file)=> file.isDataType and @imports[file.pathAbs]
			dataFiles.map (file)=>
				statements = @imports[file.pathAbs]
				someExtract = statements.some((s)-> s.extract)
				allExtract = someExtract and statements.every((s)-> s.extract)

				if statements.length > 1
					if someExtract and REGEX.commonExport.test(file.content)
						file.setContent file.ast.content.replace(REGEX.commonExport, '').replace(REGEX.endingSemi, '')
					

					if allExtract
						extracts = statements.map('extract').unique()
						file.setContent JSON.stringify new ()-> @[key] = file.extract(key, true) for key in extracts; @
					
					else if someExtract
						extracts = statements.filter((s)-> s.extract).map('extract').unique()
						for key in extracts
							extract = file.extract(key,true)
							file.parsed[key] = extract
						file.setContent JSON.stringify file.parsed

					file.setContent "module.exports = #{file.content}"


		.then ()-> # perform dedupe
			return if not @options.dedupe
			dupGroups = @statements.filter((s)-> s.kind isnt 'excluded').groupBy('target.hashPostTransforms')
			dupGroups = Object.filter dupGroups, (group)-> group.length > 1
			
			for h,group of dupGroups
				continue if group.some((s)-> s.target.options.dedupe is false)
				for statement,index in group when index > 0
					statement.target = group[0].target
			return
		
		.then ()-> @imports
		.tap ()-> debug "done calculating import tree"

exports.getFinalFiles = ()->
	@statements
		.filter (statement)=> statement.type is 'module' and statement.kind isnt 'excluded' and statement.target isnt @entryFile
		.unique('target')
		.map('target')
		.append(@entryFile, 0)

exports.compile = ()->
	builders = require('../builders')
	
	Promise.bind(@)
		.then @calcImportTree
		.tap ()-> debug "start replacing statements"
		.return @entryFile
		.then @replaceStatements
		.tap ()-> debug "done replacing statements"
		.then @prepareSourceMap
		.then @getFinalFiles
		.tap (files)->
			if files.length is 1 and @entryFile.type isnt 'module' and Object.keys(@requiredGlobals).length is 0
				promiseBreak(@generate @entryFile.ast)
		
		.tap ()-> debug "creating bundle AST"
		.then (files)-> builders.bundle(@, files)
		.tap ()-> debug "generating code from bundle AST"
		.then @generate
		.catch promiseBreak.end
		.then @applyFinalTransforms
		.then @attachVersions
		.then @attachSourceMap
		.then @attachShebang
		.then @formatOutput
		.tap ()-> setTimeout @destroy.bind(@)





