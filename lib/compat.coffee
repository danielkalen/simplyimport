through = require 'through2'
promiseBreak = require 'promise-break'

transform = (file, opts)->
	attachSourceMap = opts?._flags?.debug
	chunks = []
	through(
		(chunk, enc, done)->
			chunks.push(chunk); done()
		
		(done)->
			compile(file, Buffer.concat(chunks).toString(), attachSourceMap)
				.then (compiled)=> @push(compiled)
				.then done
	)


compile = (file, src, attachSourceMap)->
	require './patches'
	Parser = require './external/parser'
	task = new (require './task')({src:src, file:file})
	
	Promise.bind(task)
		.then task.initEntryFile
		.then task.processFile
		.then task.scanImportsExports
		.then task.calcImportTree
		.then ()->
			Promise.bind(file=task.entryFile)
				.then ()-> task.replaceInlineImports(file, true)
				.then file.ES6ImportsToCommonJS
				.then file.normalizeImportPaths
				.then file.saveContent
				.then ()-> promiseBreak(file.content) if not attachSourceMap
				.then file.genAST
				.then file.adjustASTLocations
				.then ()-> Parser.generate file.AST, sourceMap:true, sourceMapWithCode:true, sourceContent:file.contentOriginal
				.then ({code, map})->
					sourceMap = require('convert-source-map')
						.fromObject(map)
						.toComment()

					code += "\n#{sourceMap}"

				.catch promiseBreak.end











module.exports = transform