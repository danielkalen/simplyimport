

module.exports = safeRequire = (targetPath, basedir)->
	if basedir
		require(Path.join(basedir, targetPath))
	
	else if targetPath.includes('.') or targetPath.includes('/')
		require(Path.resolve(targetPath))
	
	else
		require(targetPath)