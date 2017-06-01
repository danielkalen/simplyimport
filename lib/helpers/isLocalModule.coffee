

module.exports = isLocalModule = (moduleName)->
	return moduleName.startsWith('/') or moduleName.includes('./')