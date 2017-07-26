Path = require 'path'
Promise = require 'bluebird'
promiseBreak = require 'promise-break'
helpers = require('./')
EXTENSIONS = require '../constants/extensions'
fs = require 'fs-jetpack'
chalk = require 'chalk'
debug = require('debug')('simplyimport:fs')

module.exports = resolveFilePath = (input, entryContext, cache, suppliedPath)->
	params = Path.parse(Path.resolve(input))
	isFile = false
	
	Promise.resolve()
		.then ()-> if input.startsWith('http://') or input.startsWith('https://')
			helpers.resolveHttpFile(input).then (result)->
				params = Path.parse(Path.resolve(input))
				input = result
				isFile = true
				promiseBreak(result)

		.then ()-> # resovle provided input if it has a valid extension
			extname = params.ext.slice(1).toLowerCase()
			if extname and EXTENSIONS.all.includes(extname)
				isFile = true
				promiseBreak(input)

		.tap ()-> debug "attempting to resolve extension-less path #{chalk.dim input}"
		.then ()->
			helpers.getDirListing(params.dir, cache)
		
		.then (dirListing)-> # if the dir has a single match then return it, otherwise find closest match
			candidates = if not dirListing then [] else dirListing.filter (targetPath)-> targetPath.includes(params.base)

			if candidates.length
				exactMatch = candidates.find(params.base) # Can be dir or file i.e. if provided /path/to/module and /path/to contains 'module.js' or 'module'
				fileMatch = candidates.find (targetPath)->
					fileNameSplit = targetPath.replace(params.base, '').split('.')
					return !fileNameSplit[0] and # esnrues path is not a dir (most likely as it doesn't have an ext)
							fileNameSplit.length is 2 and # ensures path is exactly the inputPath+extname
							targetPath[0] isnt '.' # ensures isnt a base-less name like /.bin

				if fileMatch
					return Path.join(params.dir, fileMatch)
				else if exactMatch
					return Path.join(params.dir, exactMatch)

			return input
		
		.tap (resolved)-> debug "best match is #{chalk.dim resolved}"
		.catch promiseBreak.end
		.tap (resolvedPath)-> debug "resolving #{chalk.dim resolvedPath}", isFile: if isFile then 'yes' else 'undecided'
		.tap (resolvedPath)-> promiseBreak(resolvedPath) if isFile
		.then (resolvedPath)->
			Promise.resolve()
				.then ()-> fs.inspectAsync(resolvedPath)
				.tap (stats)-> promiseBreak(input) if not stats
				.tapCatch ()-> debug "no path stats available for #{chalk.dim resolvedPath}"
				.tap (stats)-> promiseBreak(resolvedPath) if stats.type isnt 'dir'
				.tap (stats)-> debug "scanning dir #{chalk.dim resolvedPath}"
				.then ()-> helpers.getDirListing(resolvedPath, cache)
				.then (dirListing)->
					indexFile = dirListing.find (file)-> file.includes('index')
					return Path.join(params.dir, params.base, if indexFile then indexFile else 'index.js')
				.tap (resolvedPath)-> debug "using index file #{chalk.dim resolvedPath}"

		.catch promiseBreak.end
		.then (pathAbs)->
			helpers.newPathConfig pathAbs, entryContext, {suppliedPath}



