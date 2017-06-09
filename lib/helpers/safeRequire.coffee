Promise = require 'bluebird'
promiseBreak = require 'promise-break'
Path = require 'path'
fs = require 'fs-jetpack'
helpers = require './'

module.exports = safeRequire = (targetPath, basedir)->
	Promise.resolve()
		.then ()-> helpers.resolveModulePath(targetPath, basedir)
		.get 'file'
		.tap (resolvedPath)-> promiseBreak(resolvedPath) if fs.exists(resolvedPath)

		.then ()-> helpers.resolveFilePath(targetPath, '')
		.get 'pathAbs'
		.tap (resolvedPath)-> promiseBreak(resolvedPath) if fs.exists(resolvedPath)
		
		.then ()-> helpers.resolveFilePath(Path.resolve(basedir, targetPath), '').get('pathAbs')
		.get 'pathAbs'

		.catch promiseBreak.end
		.then (resolvedPath)->
			console.log resolvedPath, targetPath
			require(resolvedPath)

		.catch (err)->
			if err.message.includes('Cannot find module')
				throw new Error "'#{targetPath}' could not be found"
			else
				throw err