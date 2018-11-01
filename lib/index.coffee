require('./patches')
global.Promise = require('bluebird').config warnings:false, longStackTraces:!!process.env.PROMISE_DEBUG
Path = require './helpers/path'
formatError = require './external/formatError'
Task = require './task'
REGEX = require './constants/regex'
helpers = require './helpers'
{EMPTY_STUB} = require('./constants')

SimplyImport = ()->
	SimplyImport.bundle(arguments...)


SimplyImport.task = (options)->
	task = new Task(options)
	Promise.bind(task)
		.then task.initEntryFile
		.return task


SimplyImport.bundle = (options, returnStream)->
	task = new Task(options)

	taskPromise = 
	Promise.bind(task)
		.then task.initEntryFile
		.then task.processFile
		.then task.scanStatements
		.then task.compile

	if not returnStream
		return taskPromise
	else
		stream = require('through2')()
		taskPromise.then (result)-> stream.write(result, 'utf8'); stream.end()
		return stream


SimplyImport.scan = (options)->
	options.matchAllConditions ?= true
	options.ignoreErrors ?= true
	options.ignoreMissing ?= true
	options.relativePaths ?= false
	options.flat ?= true
	options.cyclic ?= false
	options.time ?= false
	options.content ?= false
	options.depth ?= 0
	task = new Task(options)

	resolveImportPath = (file)->
		context = file.context
		context = Path.relative(process.cwd(), context) if options.relativePaths
		return Path.join(context, file.pathBase)

	Promise.bind(task)
		.then task.initEntryFile
		.then task.processFile
		.then ()-> task.scanStatements(task.entryFile, options.depth)
		.then task.calcImportTree
		.then ()->
			if options.flat
				Object.values(task.imports)
					.flatten()
					.map('target')
					.filter (file)-> file.pathAbs isnt EMPTY_STUB
					.map(resolveImportPath)
					.unique()
			else
				output = []
				output.entry = file:task.entryFile.pathAbs, imports:output
				output.entry.time = task.entryFile.time if options.time
				output.entry.content = task.entryFile.content if options.content
				includedFiles = {}
				includedFiles[task.entryFile.pathAbs] = output.entry
				
				walkImports = (file, output)->
					includedFiles[file.pathAbs] ?= 'Cyclic'
					fileImports = file.statements
						.filter (s)-> s.target isnt s.source
						.map 'target'
						.unique()

					for child in fileImports# when child isnt file
						continue if child.pathAbs is EMPTY_STUB
						
						if not includedFiles[child.pathAbs]
							output.push childData = includedFiles[child.pathAbs] = 'file':resolveImportPath(child), 'imports':[]
							childData.time = child.time if options.time
							childData.content = child.content if options.content
							walkImports(child, childData.imports)

						else if options.cyclic
							output.push includedFiles[child.pathAbs]

				walkImports(task.entryFile, output)
				return output

		.tap ()-> setTimeout task.destroy.bind(task)



module.exports = SimplyImport
module.exports.defaults = require('./task/defaults')