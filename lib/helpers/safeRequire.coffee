Promise = require 'bluebird'
promiseBreak = require 'promise-break'
Path = require 'path'
fs = require 'fs-jetpack'
helpers = require './'

module.exports = safeRequire = (targetPath, context)->
	resolved = targetPath

	Promise.resolve()
		.then ()-> helpers.resolveModulePath(targetPath, {context})
		.get 'file'
		.tap (resolvedPath)-> promiseBreak(resolvedPath) if fs.exists(resolvedPath)
		
		.then ()-> helpers.resolveModulePath(targetPath, {context:Path.resolve(context,'node_modules')})
		.get 'file'
		.tap (resolvedPath)-> promiseBreak(resolvedPath) if fs.exists(resolvedPath)

		.then ()-> helpers.resolveFilePath(targetPath, '')
		.get 'pathAbs'
		.tap (resolvedPath)-> promiseBreak(resolvedPath) if fs.exists(resolvedPath)
		
		.then ()-> helpers.resolveFilePath(Path.resolve(context, targetPath), '').get('pathAbs')
		.tap (resolvedPath)-> promiseBreak(resolvedPath) if fs.exists(resolvedPath)
		.get 'pathAbs'
		
		.then ()-> helpers.resolveFilePath(Path.resolve(context, 'node_modules', targetPath), '').get('pathAbs')
		.get 'pathAbs'

		.catch promiseBreak.end
		.then (resolvedPath=targetPath)->
			require(resolved=resolvedPath)

		.catch (err)->
			if err.message.includes('Cannot find module') and err.message.split('\n')[0].includes(resolved)
				throw new Error "'#{targetPath}' could not be found"
			else
				throw err