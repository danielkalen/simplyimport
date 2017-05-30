Promise = require 'bluebird'
extend = require 'smart-extend'
Path = require 'path'
fs = require 'fs-jetpack'


module.exports = (dest, files)->
	if dest and not files
		files = dest
		dest = Path.resolve 'test','temp'
	
	Promise.resolve(Object.keys(files))
		.map (fileName)-> fs.writeAsync Path.join(dest, fileName), files[fileName]
		.return(dest)




