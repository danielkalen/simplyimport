fs = require 'fs-jetpack'
os = require 'os'
path = require 'path'

temp = ()->
	tmpDir = path.resolve os.tmpdir(),'simplyimport'
	fs.dir(tmpDir)
	return tmpDir

module.exports = temp.once()