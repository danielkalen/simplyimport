try
	global.Promise = require 'bluebird'
	axios = require 'axios'
	path = require 'path'
	spawn = require('child_process').spawn
	tar = require 'tar.gz'
	fs = require 'fs-jetpack'
	modules = 
		'coffeeify': 'https://registry.npmjs.org/coffeeify/-/coffeeify-2.1.0.tgz'
catch
	process.exit(0) # Indicates this package was not installed as a dev dependency so these modules are not necessary

Promise.resolve()
	.then ()->
		Promise.map Object.keys(modules), (module)->
			url = modules[module]
			destDir = path.resolve 'test','helpers','node_modules',module

			axios.get(url, responseType:'stream')
				.tap ()-> fs.dirAsync(destDir)
				.then (res)-> new Promise (resolve, reject)->
					unpack = res.data.pipe tar({},strip:1).createWriteStream(destDir)
					unpack.on 'end', resolve
					unpack.on 'error', reject

				.then ()-> new Promise (resolve, reject)->
					install = spawn('npm', ['install', '--only=production'], {cwd:destDir, stdio:'inherit'})
					install.on 'error', reject
					install.on 'close', resolve

	.then ()->
		console.log('DONE installing sample modules')
		process.exit(0)

	.catch (err)->
		console.error(err)
		process.exit(1)




