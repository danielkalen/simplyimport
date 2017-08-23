Path = require './path'
helpers = require('./')
{EMPTY_STUB} = require('../constants')

module.exports = normalizePackage = ({pkg, path})->
	return if not pkg
	pkg.srcPath = path
	pkg.dirPath = Path.dirname(path)
	pkg.main = 'index.js' if not pkg.main
	pkg.main = Path.resolve(pkg.dirPath, pkg.main)
	
	if pkg.browser then switch typeof pkg.browser
		when 'string'
			pkg.browser = Path.resolve(pkg.dirPath, pkg.browser) if helpers.isLocalModule(pkg.browser)
			pkg.browser = "#{pkg.main}":pkg.browser

		when 'object'
			browserField = pkg.browser
			
			for key,value of browserField
				if typeof value is 'string' and helpers.isLocalModule(value)
					browserField[key] = value = Path.resolve(pkg.dirPath, value)

				else if value is false
					browserField[key] = EMPTY_STUB

				if helpers.isLocalModule(key)
					newKey = Path.resolve(pkg.dirPath, key)
					browserField[newKey] = value
					delete browserField[key]

	return pkg


