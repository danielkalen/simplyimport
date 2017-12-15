Path = require './path'
Promise = require 'bluebird'
promiseBreak = require 'promise-break'
helpers = require('./')
EXTENSIONS = require '../constants/extensions'
fs = require 'fs-jetpack'
chalk = require 'chalk'
debug = require('../debug')('simplyimport:fs')

resolveFilePath = (input, importer)->
	params = Path.parse(Path.resolve(input))
	isFile = false

	Promise.resolve()
		.then ()-> # resovle provided input if it has a valid extension
			extname = params.ext.slice(1).toLowerCase()
			if extname and EXTENSIONS.all.includes(extname)
				isFile = true
				promiseBreak(input)

		.tap ()-> debug "attempting to resolve extension-less path #{chalk.dim input}"
		.then ()->
			fs.listAsync(params.dir)
		
		.then (dirListing)-> # if the dir has a single match then return it, otherwise find closest match
			candidates = if not dirListing then [] else dirListing.filter (targetPath)-> targetPath.includes(params.base)

			if candidates.length
				exactMatch = candidates.find(params.base) # Can be dir or file i.e. if provided /path/to/module and /path/to contains 'module.js' or 'module'
				fileMatch = matchBestCandidate candidates, (candidate)->
					nameSplit = candidate.replace(params.base, '').split('.')
					return !nameSplit[0] and # esnrues path is not a dir (most likely as it doesn't have an ext)
							nameSplit.length is 2 and # ensures path is exactly the inputPath+extname
							candidate[0] isnt '.' # ensures isnt a base-less name like /.bin

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
				.then ()-> fs.listAsync(resolvedPath)
				.then (dirListing)->
					indexFile = matchBestCandidate dirListing, (file)-> file.includes('index')
					return Path.join(params.dir, params.base, indexFile or 'index.js')

				.tap (resolvedPath)-> debug "using index file #{chalk.dim resolvedPath}"

		.catch promiseBreak.end



matchBestCandidate = (candidates, filter)->
	matches = candidates.filter(filter)

	if matches.length > 1
		jsMatch = matches.find (candidate)-> candidate.endsWith('.js')
		match = jsMatch or matches[0]
	else
		match = matches[0]

	return match



resolveFilePath = resolveFilePath.memoize (input, importer)->
	"#{importer.task.ID}/#{input}"

module.exports = (input, importer, entryContext, suppliedPath)->
	Promise.resolve()
		.then ()-> resolveFilePath(input, importer)
		.then (pathAbs)-> helpers.newPathConfig pathAbs, entryContext, {suppliedPath}



