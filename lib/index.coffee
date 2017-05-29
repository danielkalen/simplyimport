require('./sugar')
require('stack-filter').filters.push('bluebird', 'escodegen', 'esprima')
Promise = require 'bluebird'
Parser = require 'esprima'
Task = require './task'
REGEX = require './constants/regex'
helpers = require './helpers'
RegExp::test = do ()-> # RegExp::test function patch to reset index after each test
	origTestFn = RegExp::test
	return ()->
		result = origTestFn.apply(@, arguments)
		@lastIndex = 0
		return result

Parser.parseExpr = (expr, opts)->
	Parser.parse(expr, opts).body[0].expression



SimplyImport = ()->
	SimplyImport.compile(arguments...)


SimplyImport.compile = (input, options, state={})->
	task = new Task(options, input)

	Promise.bind(task)
		.then task.resolveEntryPackage
		.then task.initEntryFile
		.then task.processFile
		.then task.scanImports
		.then task.scanExports
		.then task.compile


SimplyImport.scanImports = (input, options, state={})->
	task = new Task(options, input)

	Promise.bind(task)
		.then task.resolveEntryPackage
		.then task.initEntryFile
		.then task.processFile
		.then task.scanImports
		.then ()->
			lineRefs = subjectFile.lineRefs.filter (validRef)-> validRef?

			subjectFile.imports
				.filter (validImport)-> validImport
				.sort (hashA, hashB)-> subjectFile.orderRefs.findIndex((ref)->ref is hashA) - subjectFile.orderRefs.findIndex((ref)->ref is hashB)
				.map (childHash, childIndex)->
					childPath = subjectFile.importRefs[childHash].filePath
					childPath = childPath.replace opts.context+'/', '' if not opts.withContext

					if opts.pathOnly
						return childPath
					else
						importStats = {}
						entireLine = subjectFile.contentLines[lineRefs[childIndex]]
						entireLine.replace REGEX.import, (entireLine, priorContent='', spacing='', conditions)->
							importStats = {entireLine, priorContent, spacing, conditions, path:childPath}
						
						return importStats

	



# SimplyImport.scanImports = (input, opts={})->
# 	importOptions = extend({}, defaultOptions, {recursive:false, conditions:['*']})
# 	opts = extend {}, opts, {isMain:true}

# 	Promise.resolve()
# 		.then ()->
# 			opts.context ?= if opts.isStream then process.cwd() else helpers.getNormalizedDirname(input)
# 			opts.context = PATH.resolve(opts.context) if not ['/','\\'].includes(opts.context[0])
# 			opts.context = opts.context.slice(0,-1) if opts.context[opts.context.length-1] is '/'
# 			if opts.isStream
# 				opts.suppliedPath = PATH.resolve('main.'+ if opts.isCoffee then 'coffee' else 'js')
# 			else
# 				opts.suppliedPath = input = PATH.resolve(input)
# 				opts.isCoffee ?= PATH.extname(input).toLowerCase().slice(1) is 'coffee'	
		
# 		.then ()->
# 			### istanbul ignore next ###
# 			findPkgJson(normalize:false, cwd:opts.context)
# 				.then (result)->
# 					helpers.resolvePackagePaths(result.pkg, result.path)
# 					opts.pkgFile = pkgFile = result.pkg
# 					unless opts.isStream
# 						input = pkgFile.browser[input] if typeof pkgFile.browser is 'object' and pkgFile.browser[input]
# 					delete pkgFile.browserify
				
# 				.catch ()->

# 		.then ()-> if opts.isStream then input else fs.readFileAsync(input, encoding:'utf8')

# 		.then (contents)-> new File(contents, importOptions, {}, opts)
# 		.tap (subjectFile)-> subjectFile.process()
# 		.tap (subjectFile)-> subjectFile.collectImports()
# 		.then (subjectFile)->
# 			lineRefs = subjectFile.lineRefs.filter (validRef)-> validRef?

# 			subjectFile.imports
# 				.filter (validImport)-> validImport
# 				.sort (hashA, hashB)-> subjectFile.orderRefs.findIndex((ref)->ref is hashA) - subjectFile.orderRefs.findIndex((ref)->ref is hashB)
# 				.map (childHash, childIndex)->
# 					childPath = subjectFile.importRefs[childHash].filePath
# 					childPath = childPath.replace opts.context+'/', '' if not opts.withContext

# 					if opts.pathOnly
# 						return childPath
# 					else
# 						importStats = {}
# 						entireLine = subjectFile.contentLines[lineRefs[childIndex]]
# 						entireLine.replace REGEX.import, (entireLine, priorContent='', spacing='', conditions)->
# 							importStats = {entireLine, priorContent, spacing, conditions, path:childPath}
						
# 						return importStats

				




module.exports = SimplyImport
module.exports.defaults = require('./defaultOptions')