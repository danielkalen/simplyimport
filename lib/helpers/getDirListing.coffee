Promise = require 'bluebird'
fs = require 'fs-jetpack'
helpers = require('./')

module.exports = getDirListing = (dirPath, cache)-> Promise.resolve().then ()->
	if cache?[dirPath]?
		return cache[dirPath]
	else
		Promise.resolve(fs.listAsync(dirPath))
			.tap (listing)-> cache?[dirPath] = listing
