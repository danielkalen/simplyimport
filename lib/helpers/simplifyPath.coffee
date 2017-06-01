

module.exports = simplifyPath = (targetPath)->
	targetPath.replace process.cwd()+'/', ''