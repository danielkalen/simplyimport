Promise = require 'bluebird'
extend = require 'smart-extend'
path = require 'path'
fs = require 'fs-jetpack'
helpers = {}
template =
	package: 
		name: 'samplemodule'
		version: '1.0.0'
		main: 'index.js'
	
	body: "\nmodule.exports = {name:'samplemodule'}"

helpers.createModule = ({dest, json, modules, body})->
	dest ?= path.resolve 'test','temp','samplemodule'
	packageJson = extend.clone(template.package, json)
	index = (body or '') + template.body
	
	Promise.resolve()
		.then ()-> fs.writeAsync path.resolve(dest,'package.json'), packageJson
		.then ()-> fs.writeAsync path.resolve(dest,'index.js'), index
		.then ()-> fs.dirAsync path.resolve(dest,'node_modules')
		.then ()-> if Array.isArray(modules)
			Promise.each modules, (module)->
				moduleName = path.basename(module)
				modulePath = if module is moduleName then path.resolve('node_modules',module) else module
				fs.copyAsync modulePath, path.resolve(dest,moduleName)










module.exports = helpers