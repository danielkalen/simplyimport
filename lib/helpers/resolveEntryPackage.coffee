findPkgJson = require 'read-pkg-up'
helpers = require './'

module.exports = resolveEntryPackage = (task)->
	### istanbul ignore next ###
	Promise.resolve()
		.then ()-> findPkgJson(normalize:false, cwd:task.options.context)
		.then (result)->
			helpers.resolvePackagePaths(result.pkg, result.path)
			task.options.pkgFile = pkgFile = result.pkg
			
			unless task.options.src
				if typeof pkgFile.browser is 'object' and pkgFile.browser[task.entryInput]
					task.entryInput = pkgFile.browser[task.entryInput]

			return pkgFile

		.catch ()->