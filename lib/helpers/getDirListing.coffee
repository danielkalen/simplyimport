helpers = require('./')

module.exports = getDirListing = (dirPath, fromCache)-> Promise.resolve().then ()->
	if fromCache and helpers.getDirListing.cache[dirPath]?
		return helpers.getDirListing.cache[dirPath]
	else
		Promise.resolve(fs.listAsync(dirPath))
			.tap (listing)-> helpers.getDirListing.cache[dirPath] = listing
