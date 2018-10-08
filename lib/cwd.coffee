module.exports = 
	actual: process.cwd()
	current: process.cwd()
	set: (target)-> process.chdir @current = target
	restore: ()-> process.chdir @current = @actual