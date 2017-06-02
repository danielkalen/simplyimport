Path = require 'path'
Promise = require 'bluebird'
promiseBreak = require 'promise-break'
helpers = require('./')
EXTENSIONS = require '../constants/extensions'
fs = require 'fs-jetpack'

module.exports = resolveFilePath = (input, entryContext, cache)->
	params = Path.parse(input)
	isFile = false
	
	Promise.resolve()
		.then ()-> # resovle provided input if it has a valid extension
			extname = params.ext.slice(1).toLowerCase()
			if extname and EXTENSIONS.all.includes(extname)
				isFile = true
				promiseBreak(input)

		.then ()->
			helpers.getDirListing(params.dir, cache)
		
		.then (dirListing)-> # if the dir has a single match then return it, otherwise find closest match
			candidates = dirListing.filter (targetPath)-> targetPath.includes(params.base)

			if candidates.length
				exactMatch = candidates.find(params.base) # Can be dir or file i.e. if provided /path/to/module and /path/to contains 'module.js' or 'module'
				fileMatch = candidates.find (targetPath)->
					fileNameSplit = targetPath.replace(params.base, '').split('.')
					return !fileNameSplit[0] and fileNameSplit.length is 2 # Ensures the path is not a dir and is exactly the inputPath+extname

				if fileMatch
					return Path.join(params.dir, fileMatch)
				else if exactMatch
					return exactMatch

			return input
		
		.catch promiseBreak.end
		.tap (resolvedPath)-> promiseBreak(resolvedPath) if isFile
		.then (resolvedPath)->
			Promise.resolve()
				.then ()-> fs.inspectAsync(resolvedPath)
				.tap (stats)-> promiseBreak(input) if not stats
				.tap (stats)-> promiseBreak(resolvedPath) if stats.type isnt 'dir'
				.then ()-> helpers.getDirListing(resolvedPath, cache)
				.then (dirListing)->
					indexFile = dirListing.find (file)-> file.includes('index')
					return Path.join(params.dir, params.base, if indexFile then indexFile else 'index.js')

		.catch promiseBreak.end
		.then (pathAbs)->
			context = helpers.getNormalizedDirname(pathAbs)
			contextRel = context.replace(entryContext+'/', '')
			path = helpers.simplifyPath(pathAbs)
			pathRel = pathAbs.replace(entryContext+'/', '')
			pathExt = Path.extname(pathAbs).toLowerCase().slice(1)
			pathExt = 'yml' if pathExt is 'yaml'
			pathBase = Path.basename(pathAbs)
			suppliedPath = input
			return {pathAbs, path, pathRel, pathBase, pathExt, context, contextRel, suppliedPath}
