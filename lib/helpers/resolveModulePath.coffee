Path = require 'path'
findPkgJson = require 'read-pkg-up'
Promise = require 'bluebird'
helpers = require('./')
{EMPTY_FILE, EMPTY_FILE_END} = require('../constants')
coreModuleShims = require('../constants/coreShims')
extensions = require('../constants/extensions').all.map (ext)-> ".#{ext}"

module.exports = resolveModulePath = (moduleName, basedir, basefile, pkgFile, target)-> Promise.resolve().then ()->
	resolveModule = Promise.promisify if target is 'node' then require('resolve') else require('browser-resolve')
	fullPath = Path.resolve(basedir, moduleName)
	output = 'file':fullPath

	switch
		when helpers.isHttpModule(moduleName)
			helpers.resolveHttpModule(moduleName).then (result)->
				resolveModulePath(result, basedir, basefile, pkgFile, target)

		when helpers.isLocalModule(moduleName) and moduleName[moduleName.length-1] isnt '/'
			if pkgFile and typeof pkgFile.browser is 'object' and target isnt 'node'
				replacedPath = helpers.resolveBrowserFieldPath(pkgFile, moduleName, basedir)
				
				if replacedPath?
					if typeof replacedPath isnt 'string'
						output.file = EMPTY_FILE
						output.isEmpty = true
					else
						output.file = replacedPath

			output.pkg = pkgFile
			return output

		else
			resolveModule(moduleName, {basedir, filename:basefile, modules:coreModuleShims, extensions})
				.then (moduleFullPath)->
					findPkgJson(normalize:false, cwd:moduleFullPath).then (result)->
						output.file = moduleFullPath
						output.pkg = result.pkg
						
						if moduleFullPath.endsWith EMPTY_FILE_END
							output.isEmpty = true
							delete output.pkg
						else
							helpers.resolvePackagePaths(result.pkg, result.path)
						
						return output

				.catch(
					(err)-> err.message.startsWith('Cannot find module')
					()->
						if helpers.isLocalModule(moduleName)
							return output
						else
							helpers.resolveModulePath("./#{moduleName}", basedir, basefile, pkgFile, target)
				)