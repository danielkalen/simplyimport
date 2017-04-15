Promise = require 'bluebird'
extend = require 'smart-extend'
path = require 'path'
fs = require 'fs-jetpack'
template =
	package: 
		name: 'samplemodule'
		version: '1.0.0'
		main: 'index.js'
	
	body: "\nmodule.exports = {name:'samplemodule'}"


module.exports = ({dest, json, modules, files, body, replaceBody})->
	dest ?= path.resolve 'test','temp','samplemodule'
	packageJson = extend.clone(template.package, json)
	index = (body or '') + (if replaceBody then '' else template.body)
	
	Promise.resolve()
		.then ()-> fs.writeAsync path.resolve(dest,'package.json'), packageJson
		.then ()-> fs.writeAsync path.resolve(dest,'index.js'), index
		.then ()-> fs.dirAsync path.resolve(dest,'node_modules')
		.then ()->
			return if typeof files isnt 'object' or not files
			Promise.each Object.keys(files), (fileName)->
				fs.writeAsync path.join(dest, fileName), files[fileName]
		
		.then ()->
			return unless Array.isArray(modules)
			Promise.each modules, (module)->
				moduleName = path.basename(module)
				modulePath = if module is moduleName then path.resolve('node_modules',module) else module
				fs.copyAsync modulePath, path.resolve(dest,'node_modules',moduleName), overwrite:true
		.return(dest)





