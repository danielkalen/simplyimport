module.exports = isHttpModule = (path)->
	path?.startsWith('http://') or path?.startsWith('https://')