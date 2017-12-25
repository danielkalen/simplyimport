Promise = require 'bluebird'
extend = require 'smart-extend'
Path = require 'path'
fs = require 'fs-jetpack'


module.exports = (dest, files)->
	if dest and not files
		files = dest
		dest = Path.resolve 'test','temp'
	
	Promise.resolve(Object.keys(files))
		.map (fileName)->
			content = files[fileName]
			
			if Array.isArray(content)
				content = content[1](files[content[0]])
			
			fs.writeAsync Path.resolve(dest, fileName), content
		
		.return(dest)




