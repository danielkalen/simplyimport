Promise = require 'bluebird'
promiseBreak = require 'promise-break'
debug = require('../debug')('simplyimport:task')


exports.scanInlineStatements = (file)->
	file.scannedForceInlineImports = true
	Promise.bind(@)
		.then ()-> file.collectForceInlineImports()
		.tap (imports)-> @inlineStatements.push(imports...)
		.map (statement)->
			Promise.bind(@)
				.then ()-> @initFile(statement.target, file, true)
				.then (childFile)-> @processFile(childFile)
				.then (childFile)-> statement.target = childFile
				.catch message:'excluded', ()-> statement.type = 'inline-forced'; statement.kind = 'excluded'
				.catch message:'ignored', @handleIgnoredFile.bind(@, file, statement)
				.catch message:'missing', @handleMissingFile.bind(@, file, statement)
				.return(statement)
		
		.filter (statement)-> statement.kind isnt 'excluded' and not statement.target.scannedForceInlineImports
		.map (statement)-> @scanInlineStatements(statement.target)
		.catch promiseBreak.end
		.catch (err)-> @emit 'GeneralError', file, err
		.return(@inlineStatements)


exports.scanStatements = (file, depth=Infinity, currentDepth=0)-> if not file.scannedImportsExports
	file.scannedImportsExports = true
	collected = []
	
	Promise.bind(@)
		.then ()-> file.preCollection()
		.then ()-> file.collectImports()
		.tap (imports)-> collected.push(imports...)
		
		.then ()-> file.collectExports()
		.filter (statement)-> statement.target isnt statement.source
		.tap (exports)-> collected.push(exports...)

		.tap ()-> file.resolveNestedStatements()
		
		.then ()-> @statements.push(collected...)
		.return collected
		.map (statement)->
			Promise.bind(@)
				.then ()-> @initFile(statement.target, statement.source)
				.tap (childFile)-> resetFile(childFile) if childFile.type is 'inline-forced'
				.then (childFile)-> @processFile(childFile)
				.then (childFile)-> statement.target = childFile
				.catch message:'excluded', ()-> statement.type = 'module'; statement.kind = 'excluded'
				.catch message:'ignored', @handleIgnoredFile.bind(@, statement.source, statement)
				.catch message:'missing', @handleMissingFile.bind(@, statement.source, statement)
				.return(statement)
		
		.tap ()-> promiseBreak(@statements) if ++currentDepth > depth
		.map (statement)-> @scanStatements(statement.target, depth, currentDepth) unless statement.kind is 'excluded'
		.then ()-> file.postScans()
		
		.catch promiseBreak.end
		.catch (err)-> @emit 'GeneralError', file, err
		.return(@statements)



exports.replaceInlineStatements = (file)->
	return file if file.replacedInlineStatements
	file.replacedInlineStatements = true
	
	Promise.resolve(file.inlineStatements).bind(file)
		.map (statement)=> @replaceInlineStatements(statement.target) unless statement.kind is 'excluded'
		.then file.replaceInlineStatements



exports.replaceStatements = (file)->
	return file if file.replacedStatements
	file.replacedStatements = true
	
	Promise.resolve(file.statements).bind(file)
		.map (statement)=> @replaceStatements(statement.target) unless statement.kind is 'excluded'
		.then file.resolveReplacements
		.then file.compile			




resetFile = (file)->
	file.processed = null
	file.type = null


