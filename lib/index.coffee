require('./sugar')
require('./patches')
Promise = require 'bluebird'
formatError = require './external/formatError'
Task = require './task'
REGEX = require './constants/regex'
helpers = require './helpers'

Promise.onPossiblyUnhandledRejection (err, promise)->
	console.error formatError(err)

SimplyImport = ()->
	SimplyImport.compile(arguments...)


SimplyImport.compile = (options, returnStream)->
	task = new Task(options)

	taskPromise = 
	Promise.bind(task)
		.then task.initEntryFile
		.then task.processFile
		.then task.scanImports
		.then ()-> task.entryFile
		.then task.scanExports
		.then task.compile

	if not returnStream
		return taskPromise
	else
		stream = require('through2')()
		taskPromise.then (result)-> stream.write(result, 'utf8'); stream.end()
		return stream


SimplyImport.scan = (options)->
	options.ignoreErrors ?= true
	options.depth ?= 0
	task = new Task(options)

	Promise.bind(task)
		.then task.initEntryFile
		.then task.processFile
		.then ()-> task.scanImports(task.entryFile, options.depth)
		.then ()-> task.scanExports(task.entryFile)
		.then task.calcImportTree
		.then ()->
			task.entryFile.importStatements
				.filter (validImport)-> validImport
				.sort (hashA, hashB)-> subjectFile.orderRefs.findIndex((ref)->ref is hashA) - subjectFile.orderRefs.findIndex((ref)->ref is hashB)
				.map (childHash, childIndex)->
					childPath = subjectFile.importRefs[childHash].pathAbs
					childPath = childPath.replace opts.context+'/', '' if not opts.withContext

					if opts.pathOnly
						return childPath
					else
						importStats = {}
						entireLine = subjectFile.contentLines[lineRefs[childIndex]]
						entireLine.replace REGEX.import, (entireLine, priorContent='', spacing='', conditions)->
							importStats = {entireLine, priorContent, spacing, conditions, path:childPath}
						
						return importStats

				




module.exports = SimplyImport
module.exports.defaults = require('./defaults')