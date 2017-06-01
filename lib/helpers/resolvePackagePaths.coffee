helpers = require('./')

module.exports = resolvePackagePaths = (pkgFile, pkgPath)->
	pkgFile.srcPath = pkgPath
	pkgFile.dirPath = Path.dirname(pkgPath)
	pkgFile.main = 'index.js' if not pkgFile.main
	pkgFile.main = Path.resolve(pkgFile.dirPath, pkgFile.main)
	
	if pkgFile.browser then switch typeof pkgFile.browser
		when 'string'
			pkgFile.browser = pkgFile.main = Path.resolve(pkgFile.dirPath, pkgFile.browser)

		when 'object'
			browserField = pkgFile.browser
			
			for key,value of browserField
				if typeof value is 'string'
					browserField[key] = value = Path.resolve(pkgFile.dirPath, value)

				if helpers.isLocalModule(key)
					newKey = Path.resolve(pkgFile.dirPath, key)
					browserField[newKey] = value
					delete browserField[key]

	return