require('./patches')
Promise = require 'bluebird'
Promise.config longStackTraces:true if process.env.DEBUG
Path = require 'path'
formatError = require './external/formatError'
Task = require './task'
REGEX = require './constants/regex'
helpers = require './helpers'
{EMPTY_STUB} = require('./constants')

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
		.then task.scanImportsExports
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
	options.depth ?= 0
	task = new Task(options)

	resolveImportPath = (file)->
		context = file.context
		context = Path.relative(process.cwd(), context) if options.relativePaths
		return Path.join(context, file.pathBase)

	Promise.bind(task)
		.then task.initEntryFile
		.then task.processFile
		.then ()-> task.scanImportsExports(task.entryFile, options.depth)
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
				includedFiles = {}
				includedFiles[task.entryFile.pathAbs] = file:task.entryFile.pathAbs, imports:output
				
				walkImports = (file, output)->
					includedFiles[file.pathAbs] ?= 'Cyclic'
					fileImports = file.importStatements.map('target')
					fileExports = file.exportStatements.filter((s)-> s.target isnt s.source).map('target')
					fileImports = fileImports.concat(fileExports).unique()

					for child in fileImports# when child isnt file
						continue if child.pathAbs is EMPTY_STUB
						
						if not includedFiles[child.pathAbs]
							output.push childData = includedFiles[child.pathAbs] = 'file':resolveImportPath(child), 'imports':[]
							childData.time = child.time if options.time
							walkImports(child, childData.imports)

						else if options.cyclic
							output.push includedFiles[child.pathAbs]

				walkImports(task.entryFile, output)
				return output




module.exports = SimplyImport
module.exports.defaults = require('./defaults')