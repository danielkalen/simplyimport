Path = require 'path'
findPkgJson = require 'read-pkg-up'
Promise = require 'bluebird'
resolveModule = Promise.promisify require('browser-resolve')
helpers = require('./')
EMPTY_FILE_END = Path.join('node_modules','browser-resolve','empty.js')
EMPTY_FILE = Path.resolve(__dirname,'..',EMPTY_FILE_END)
coreModuleShims = require('../constants/coreShims')(EMPTY_FILE)

module.exports = resolveModulePath = (moduleName, basedir, basefile, pkgFile)-> Promise.resolve().then ()->
	fullPath = Path.resolve(basedir, moduleName)
	output = 'file':fullPath
	
	if helpers.isLocalModule(moduleName)
		if pkgFile and typeof pkgFile.browser is 'object'
			replacedPath = pkgFile.browser[fullPath]
			replacedPath ?= pkgFile.browser[fullPath+'.js']
			replacedPath ?= pkgFile.browser[fullPath+'.ts']
			replacedPath ?= pkgFile.browser[fullPath+'.coffee']
			
			if replacedPath?
				if typeof replacedPath isnt 'string'
					output.file = EMPTY_FILE
					output.isEmpty = true
				else
					output.file = replacedPath

		output.pkg = pkgFile
		return output

	else		
		resolveModule(moduleName, {basedir, filename:basefile, modules:coreModuleShims})
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
				()-> helpers.resolveModulePath("./#{moduleName}", basedir, basefile, pkgFile)
			)