Path = require './path'

module.exports = getNormalizedDirname = (targetPath)->
	Path.normalize Path.dirname Path.resolve(targetPath)