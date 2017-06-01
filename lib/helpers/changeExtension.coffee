

module.exports = changeExtension = (pathAbs, extension)->
	pathAbs = pathAbs.replace(/\.\w+?$/,'')
	return "#{pathAbs}.#{extension}"