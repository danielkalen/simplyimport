chalk = require 'chalk'
labels = 
	'usage': chalk.bgYellow.black('Usage')
	'directive': chalk.bgGreen.black('Directive Syntax')
	'examples': chalk.bgCyan.black('Directive Examples')

values =
	'usage': "simplyimport -i #{chalk.italic.dim('<input>')} -o #{chalk.italic.dim('<output>')} -[c|u|r|p|s|C]"
	'directive': "import [#{chalk.italic.dim('<conditions>')}] #{chalk.italic.dim('<filepath>')}"
	'examples': [
		"import 'parts/someFile.js'"
		"import 'parts/someFile.coffee'"
		"import parts/someFile"
		"import ../../parts/someFile"
		"import [conditionA, conditionB] parts/someFile.js"
		"var foo = import parts/someLibrary.js"
	]
	.map (str)-> chalk.dim(str)
	.join '\n      '





module.exports = [
	"#{labels.usage} #{values.usage}"
	"#{labels.directive} #{values.directive}"
	"#{labels.examples}\n      #{values.examples}"
].join '\n'




