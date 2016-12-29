chalk = require 'chalk'
orLabel = " #{chalk.bold.bgWhite.black 'OR'} "
labels = 
	'usage': chalk.bgYellow.black('Usage')
	'importDirective': chalk.bgGreen.black('Import Syntax')
	'importExamples': chalk.bgCyan.black('Import Examples')
	'exportDirective': chalk.bgGreen.black('Export Syntax')
	'exportExamples': chalk.bgCyan.black('Export Examples')

values =
	'usage': "simplyimport -i #{chalk.italic.dim('<input>')} -o #{chalk.italic.dim('<output>')} -[c|u|r|p|s|C]"
	'importDirective': "import [#{chalk.italic.dim('<conditions>')}] [#{chalk.italic.dim('<defaultMember> {<members>}')}] #{chalk.italic.dim('<file/module path>')} #{orLabel} require(#{chalk.italic.dim('<file/module path>')})"
	'importExamples': [
		"import 'parts/someFile.js'"
		"import 'parts/someFile.coffee'"
		"import parts/someFile"
		"import * as customExports from ../../parts/someFile"
		"import {readFile, readdir as readDir} from 'fs'"
		"import [conditionA, conditionB] parts/someFile.js"
		"var foo = import parts/someLibrary.js"
		"require('../parts/someFile')"
	].map((str)-> chalk.dim(str)).join '\n      '
	'exportDirective': "export [#{chalk.italic.dim('default')}] [#{chalk.italic.dim('{<members>}')}] #{chalk.italic.dim('...')} #{orLabel} exports #{orLabel} exports[#{chalk.italic.dim('name')}] #{orLabel} module.exports[#{chalk.italic.dim('name')}] = #{chalk.italic.dim('...')}"
	'exportExamples': [
		"export var abc = '123'"
		"export default function(){}"
		"export function fnName = ()=> 123"
		"export {aaa, bbb as BBB, ccc}"
		"exports = {'aaa':aaa, 'BBB':bbb}"
		"module.exports['ddd'] = 'ddd'"
		"module.exports.eee = 'eee'"
	].map((str)-> chalk.dim(str)).join '\n      '





module.exports = [
	"#{labels.usage} #{values.usage}"
	"#{labels.importDirective} #{values.importDirective}"
	"#{labels.importExamples}\n      #{values.importExamples}\n"
	"#{labels.exportDirective} #{values.exportDirective}"
	"#{labels.exportExamples}\n      #{values.exportExamples}"
].join '\n'




