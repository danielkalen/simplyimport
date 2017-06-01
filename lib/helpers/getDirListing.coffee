Promise = require 'bluebird'
fs = require 'fs-jetpack'
helpers = require('./')
cache = Object.create(null)

module.exports = getDirListing = (dirPath, fromCache)-> Promise.resolve().then ()->
	if fromCache and cache[dirPath]?
		return cache[dirPath]
	else
		Promise.resolve(fs.listAsync(dirPath))
			.tap (listing)-> cache[dirPath] = listing
