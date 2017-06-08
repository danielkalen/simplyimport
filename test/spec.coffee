global.Promise = require 'bluebird'
fs = require 'fs-jetpack'
helpers = require './helpers'
path = require 'path'
chalk = require 'chalk'
mocha = require 'mocha'
chai = require 'chai'
chaiSpies = require 'chai-spies'
chai.use chaiSpies
vm = require('vm')
expect = chai.expect
coffeeCompiler = require 'coffee-script'
Streamify = require 'streamify-string'
Browserify = require 'browserify'
Browserify::bundleAsync = Promise.promisify(Browserify::bundle)
regEx = require '../lib/constants/regex'
exec = require('child_process').exec
stackTraceFilter = require('stack-filter')
stackTraceFilter.filters.push('bluebird')
nodeVersion = parseFloat(process.version[1])
badES6Support = nodeVersion < 6
bin = path.resolve 'bin'
SimplyImport = require '../'

# origFail = mocha.Runner::fail
# mocha.Runner::fail = (test, err)->
# 	err.stack = stackTraceFilter.filter(err.stack).join('\n')
# 	origFail.call(@, test, err)
sample = ()-> path.join __dirname,'samples',arguments...
temp = ()-> path.join __dirname,'temp',arguments...
tempFile = (fileNames...)->
	path.join 'test','temp',path.join(fileNames...)

debugFile = (fileNames...)->
	path.join 'test','debug',path.join(fileNames...)


importAndRunAsScript = (opts, filename='script.js')->
	SimplyImport(opts).then (compiledResult)->
		Promise.resolve()
			.then ()-> (new vm.Script(compiledResult, {filename:filename})).runInThisContext()
			.return(compiledResult)
			.catch (err)->
				debugPath = debugFile(filename)
				err.message += "\nSaved compiled result to '#{debugPath}'"
				fs.writeAsync(debugPath, compiledResult).timeout(500)
					.catch ()-> err
					.then ()-> throw err


suite "SimplyImport", ()->
	suiteTeardown ()-> fs.removeAsync(temp())
	suiteSetup ()-> fs.dirAsync(temp('output')).then ()->
		Promise.all [
			fs.writeAsync temp('someFile.js'), 'abc123'
			fs.writeAsync temp('someFile2.js'), 'def456'
		]




	suite "VanillaJS", ()->
		test "Unquoted imports that have whitespace after them should not make any difference", ()->
			SimplyImport(src:"importInline 'test/temp/someFile.js'\t").then (result)->
				expect(result).to.equal "abc123\t"


		test "Imports surrounded by parentheses should not make any difference", ()->
			Promise.resolve()
				.then ()-> fs.writeAsync(tempFile('string.js'), "'abc123def'")
				.then ()-> SimplyImport(src:"var varResult = (import 'test/temp/string.js').toUpperCase()")
				.then (result)->
					eval(result)
					expect(varResult).to.equal "ABC123DEF"
				
				.then ()-> SimplyImport(src:"(import 'test/temp/string.js').toUpperCase()")
				.then (result)->
					expect(eval(result)).to.equal "ABC123DEF"
			
				.then ()-> SimplyImport(src:" (import 'test/temp/string.js').toUpperCase()")
				.then (result)->
					expect(eval(result)).to.equal "ABC123DEF"



		test.skip "Imports can end with a semicolon", ()->
			fs.writeAsync(tempFile('string.js'), "'abc123def'").then ()->
				SimplyImport("import test/temp/string.js;", null, {isStream:true}).then (result)->
					expect(result).to.equal "'abc123def'"



		test.skip "An import statement can be placed after preceding content", ()->
			SimplyImport("var imported = import test/temp/someFile.js", null, {isStream:true}).then (result)->
				expect(result).to.equal "var imported = abc123"



		test.skip "An import statement with non-ExpressionStatement contents that is placed after preceding content will be wrapped in a IIFE closure", ()->
			fs.writeAsync(tempFile('nonExpression.js'), "var thisShallBeReturned = 'abc123'").then ()->
				SimplyImport("var imported = import test/temp/nonExpression.js", null, {isStream:true}).then (result)->
					eval(result)
					expect(imported).to.equal 'abc123'
					
					fs.writeAsync(tempFile('semiExpression.js'), "var thisShallBeReturned = 'abc123',ALIAS; ALIAS = thisShallBeReturned").then ()->
						SimplyImport("var imported2 = import test/temp/semiExpression.js", null, {isStream:true}).then (result)->
							eval(result)
							expect(imported2).to.equal 'abc123'



		test.skip "Duplicate imports will cause the imported file to be wrapped in an IIFE and have its last statement returned with all imports referencing the return value", ()->
			invokeCount = 0
			expectation = null
			invokeFn = (result)->
				invokeCount++
				expect(result).to.equal expectation

			adjustResult = (result, minIndex)->
				result.replace /\_s\$m\(\d+\)/g, (entire)-> "invokeFn(#{entire})"

			fs.writeAsync(tempFile('fileA.js'), "var output = 'varLess'").then ()->
				SimplyImport("import 'test/temp/fileA.js'\n".repeat(2), null, {isStream:true}).then (result)->
					expect(result.startsWith "var output = 'varLess'").to.be.false
					expectation = 'varLess'
					eval(adjustResult(result))
					expect(invokeCount).to.equal 2

					fs.writeAsync(tempFile('fileB.js'), "var output = 'withVar'").then ()->
						SimplyImport("import 'test/temp/fileB.js'\n".repeat(2), null, {isStream:true}).then (result)->
							expect(result.startsWith "var output = 'withVar'").to.be.false

							expectation = 'withVar'
							eval(adjustResult(result))
							expect(invokeCount).to.equal 4

						fs.writeAsync(tempFile('fileC.js'), "return 'returnStatment'").then ()->
							SimplyImport("import 'test/temp/fileC.js'\n".repeat(2), null, {isStream:true}).then (result)->
								expect(result.startsWith "return 'returnStatment'").to.be.false

								expectation = 'returnStatment'
								eval(adjustResult(result))
								expect(invokeCount).to.equal 6

								fs.writeAsync(tempFile('fileD.js'), "if (true) {output = 'condA'} else {output = 'condB'}").then ()->
									SimplyImport("import 'test/temp/fileD.js'\n".repeat(2), null, {isStream:true}).then (result)->
										expect(result.startsWith "if (true)").to.be.false

										expectation = undefined
										eval(adjustResult(result))
										expect(invokeCount).to.equal 8

										origLog = console.error
										console.error = chai.spy()
										fs.writeAsync(tempFile('fileE.js'), "var 123 = 'invalid syntax'").then ()->
											SimplyImport("import 'test/temp/fileE.js'\n".repeat(2), null, {isStream:true}).then (result)->
												expect(console.error).to.have.been.called.exactly(1)
												console.error = origLog



		test.skip "Duplicate imports references will be used even for duplicates across multiple files", ()->
			Promise.all([
				fs.writeAsync(tempFile('variable.js'), "output = 'someOutput'")
				fs.writeAsync(tempFile('importingB.js'), "import variable.js")
				fs.writeAsync(tempFile('importingA.js'), "import variable.js")
			]).then ()->
				SimplyImport("import 'test/temp/importingA.js'\nimport 'test/temp/importingB.js'\nimport 'test/temp/variable.js'", null, {isStream:true}).then (result)->
					origResult = result
					result = do ()->
						partA = result.split('\n').slice(0,4).join('\n')
						partB = result.split('\n').slice(4).join('\n')
						partA+'\n'+partB.replace /\_s\$m\(\d+\)/g, (entire)-> "invokeFn(#{entire})"

					invokeCount = 0
					invokeFn = (result)->
						invokeCount++
						expect(result).to.equal 'someOutput'
					
					eval(result)
					expect(invokeCount).to.equal 3



		test.skip "Imports can have exports (ES6 syntax) and they can be imported via ES6 syntax", ()->
			opts = {preventGlobalLeaks:false, transform:['babelify', {presets:'es2015-script', sourceMaps:false}]}

			Promise.resolve()
				.then ()->
					fs.writeAsync tempFile('exportBasic.js'), "
						var AAA = 'aaa', BBB = 'bbb', CCC = 'ccc', DDD = 'ddd';\n\
						export {AAA, BBB,CCC as ccc,  DDD as DDDDD  }\n\
						export default function(){return 33};\n\
						export function namedFn (){return 33};\n\
						export var namedFn2 = ()=> 33;\n\
						export class someClass {};\n\
						export var another = 'anotherValue'\n\
						export let kid ='kiddy';"
				.then ()->
					SimplyImport("import myDefault, { AAA,BBB, ccc as CCC,DDDDD as ddd,kid,  kiddy, another} from test/temp/exportBasic.js", opts, {isStream:true}).then (result)->
						eval(result)
						expect(AAA).to.equal 'aaa'
						expect(BBB).to.equal 'bbb'
						expect(ddd).to.equal 'ddd'
						expect(kid).to.equal 'kiddy'
						expect(kiddy).to.equal undefined
						expect(another).to.equal 'anotherValue'
						expect(myDefault()).to.equal 33
						delete AAA
						delete BBB
						delete ddd
						delete kid
						delete kiddy
						delete another
						delete myDefault

				.then ()->
					SimplyImport("import test/temp/exportBasic.js", opts, {isStream:true}).then (result)->
						eval(result)
						expect(()-> AAA).to.throw()
						expect(()-> BBB).to.throw()
						expect(()-> ddd).to.throw()
						expect(()-> kid).to.throw()
						expect(()-> kiddy).to.throw()
						expect(()-> another).to.throw()

				.then ()->
					SimplyImport("import {BBB} from test/temp/exportBasic.js\nimport {kid} from test/temp/exportBasic.js", opts, {isStream:true}).then (result)->
						eval(result)
						expect(BBB).to.equal 'bbb'
						expect(kid).to.equal 'kiddy'
						delete BBB
						delete kid

				.then ()->
					SimplyImport("import defFn from test/temp/exportBasic.js\nimport defFnAlias from test/temp/exportBasic.js", opts, {isStream:true}).then (result)->
						eval(result)
						expect(defFn()).to.equal 33
						expect(defFnAlias()).to.equal 33
						delete defFn
						delete defFnAlias

				.then ()->
					SimplyImport("import * as allExports from test/temp/exportBasic.js", opts, {isStream:true}).then (result)->
						eval(result)
						expect(typeof allExports).to.equal 'object'
						expect(allExports.AAA).to.equal 'aaa'
						expect(allExports.DDDDD).to.equal 'ddd'
						expect(allExports.namedFn()).to.equal 33
						expect(allExports.namedFn2()).to.equal 33
						expect(typeof allExports.someClass).to.equal 'function'
						expect(allExports['*default*']()).to.equal 33
						delete allExports

				.then ()->
					Promise.all([
						SimplyImport("import * as allA from test/temp/exportBasic.js", opts, {isStream:true})
						SimplyImport("var allB = import test/temp/exportBasic.js", opts, {isStream:true})
					]).then (results)->
						try
							eval(results[0])
						catch err
							console.log(results[0])
							throw err

						try
							eval(results[1])
						catch err
							console.log(results[1])
							throw err
						expect(allA).to.exist
						expect(allB).to.exist
						expect(allA.AAA).to.equal(allB.AAA)
						expect(allA.BBB).to.equal(allB.BBB)
						expect(allA.ddd).to.equal(allB.ddd)
						expect(allA.kid).to.equal(allB.kid)
						expect(allA.kiddy).to.equal(allB.kiddy)
						expect(allA.another).to.equal(allB.another)
						expect(allA.namedFn()).to.equal(allB.namedFn())
						expect(allA.namedFn2()).to.equal(allB.namedFn2())
						expect(allA['*default*']()).to.equal(allB['*default*']())

				.then ()->
					fs.writeAsync tempFile('exportAdvanced.js'), "
						var AAA = 'aaa', BBB = 'bbb', CCC = 'ccc', DDD = 'ddd';\n\
						export default {AAA, BBB,CCC as ccc,  DDD as DDDDD  }\n\
						export var another = 'anotherValue'\n\
						export let kid ='kiddy';"

				.then ()->
					SimplyImport("import theDefault,{kid as kido,another} from test/temp/exportAdvanced.js", opts, {isStream:true}).then (result)->
						try
							eval(result)
						catch err
							console.error(result)
							throw err

						expect(theDefault.AAA).to.equal 'aaa'
						expect(theDefault.BBB).to.equal 'bbb'
						expect(theDefault.ccc).to.equal 'ccc'
						expect(theDefault.DDDDD).to.equal 'ddd'
						expect(another).to.equal 'anotherValue'
						expect(kido).to.equal 'kiddy'

				.then ()->
					fs.writeAsync(tempFile('importExported.js'), "import * as allExports from exportBasic.js")

				.then ()->
					SimplyImport("require('test/temp/importExported.js');", opts, {isStream:true}).then (result)->
						result = result.replace('var allExports', 'global.theExported')
						eval(result)
						expect(typeof theExported).to.equal 'object'
						expect(theExported.AAA).to.equal 'aaa'
						expect(theExported.DDDDD).to.equal 'ddd'
						delete theExported





		test.skip "Imports can have exports (CommonJS syntax) and they can be imported via ES6 syntax", ()->
			opts = {preventGlobalLeaks:false}
			Promise.resolve()
				.then ()->
					fs.writeAsync tempFile('exportBasic.js'), "
						var AAA = 'aaa', BBB = 'bbb', CCC = 'ccc', DDD = 'ddd';\n\
						exports = module.exports = function(){return 33};\n\
						module.exports.AAA = AAA\n\
						module.exports[BBB.toUpperCase()] = BBB;\n\
						var moduleExports = exports;\n\
						moduleExports[\"kid\"] = 'kiddy'\n\
						var EEE = 'eee'; exports['CCC'] = CCC\n\
						module.exports.DDDDD = DDD;\n\
						exports.another = 'anotherValue';\n"

				.then ()->
					SimplyImport("import { AAA,BBB, ccc as CCC,DDDDD as ddd,kid,  kiddy, another} from test/temp/exportBasic.js", opts, {isStream:true}).then (result)->
						eval(result)
						expect(AAA).to.equal 'aaa'
						expect(BBB).to.equal 'bbb'
						expect(ddd).to.equal 'ddd'
						expect(kid).to.equal 'kiddy'
						expect(kiddy).to.equal undefined
						expect(another).to.equal 'anotherValue'
						delete AAA
						delete BBB
						delete ddd
						delete kid
						delete kiddy
						delete another

				.then ()->
					SimplyImport("import test/temp/exportBasic.js", opts, {isStream:true}).then (result)->
						eval(result)
						expect(()-> AAA).to.throw()
						expect(()-> BBB).to.throw()
						expect(()-> ddd).to.throw()
						expect(()-> kid).to.throw()
						expect(()-> kiddy).to.throw()
						expect(()-> another).to.throw()
					
				.then ()->
					SimplyImport("import {BBB} from test/temp/exportBasic.js\nimport {kid} from test/temp/exportBasic.js", opts, {isStream:true}).then (result)->
						eval(result)
						expect(BBB).to.equal 'bbb'
						expect(kid).to.equal 'kiddy'
						delete BBB
						delete kid
										
				.then ()->
					SimplyImport("import * as allExports from test/temp/exportBasic.js", opts, {isStream:true}).then (result)->
						eval(result)
						expect(typeof allExports).to.equal 'function'
						expect(allExports()).to.equal 33
						expect(allExports.AAA).to.equal 'aaa'
						expect(allExports.DDDDD).to.equal 'ddd'
						delete allExports
										
				.then ()->
					SimplyImport("var fetchedAAA = (import test/temp/exportBasic.js).AAA", opts, {isStream:true}).then (result)->
						eval(result)
						expect(fetchedAAA).to.equal 'aaa'
						delete fetchedAAA

				.then ()->
					Promise.all([
						SimplyImport("import * as allA from test/temp/exportBasic.js", opts, {isStream:true})
						SimplyImport("var allB = import test/temp/exportBasic.js", opts, {isStream:true})
					]).then (results)->
						eval(results[0])
						eval(results[1])
						expect(allA).to.exist
						expect(allB).to.exist
						expect(allA.AAA).to.equal(allB.AAA)
						expect(allA.BBB).to.equal(allB.BBB)
						expect(allA.ddd).to.equal(allB.ddd)
						expect(allA.kid).to.equal(allB.kid)
						expect(allA.kiddy).to.equal(allB.kiddy)
						expect(allA.another).to.equal(allB.another)
						expect(allA()).to.equal(allB())



		test.skip "CommonJS syntax imports will behave exactly the same as ES6 imports", ()->
			importLines = [
				"import 'withquotes.js'"
				"import 'withext.js'"
				"import 'noext'"
				"import 'realNoExt'"
				"import 'nested/nested1.js'"
				"import 'dir'"
				"variable = import 'variable.js'"
				"// import 'commented.js'"
			]
			requireLines = importLines.map (dec)-> dec.replace('import ', 'require(')+')'

			Promise.all([
				fs.writeAsync(tempFile('withquotes.js'), 'withquotes')
				fs.writeAsync(tempFile('withext.js'), 'withext')
				fs.writeAsync(tempFile('noext.js'), 'noext')
				fs.writeAsync(tempFile('realNoExt'), 'realNoExt')
				fs.writeAsync(tempFile('nested', 'nested1.js'), 'nested')
				fs.writeAsync(tempFile('dir/index.js'), 'dir')
				fs.writeAsync(tempFile('variable.js'), 'variable')
			]).then ()->
				Promise.all([
					SimplyImport(importLines.join('\n'), null, {isStream:true, context:'test/temp'})
					SimplyImport(requireLines.join('\n'), null, {isStream:true, context:'test/temp'})
				]).then (results)->
					expect(results[0].split('\n').slice(0,-2)).to.eql(results[1].split('\n').slice(0,-2))



		test.skip "CommonJS syntax imports cannot have dynamic expressions", ()->
			fs.writeAsync(tempFile('commonDynamic.js'), "
				var wontImport = require('some'+'File.js');\n\
				var willImport = require('someFile.js');
			").then ()->
				SimplyImport('import test/temp/commonDynamic.js', null, {isStream:true}).then (result)->
					expect(result).not.to.include("require('someFile.js')")
					expect(result).to.include("require('some'+'File.js')")



		test.skip "UMD Bundles that have require statements will not have their exports returned nor will its require statements be attended", ()->
			fileContent = "this.blankReturn = import 'jquery-selector-cache'"
			SimplyImport(fileContent, null, {isStream:true}).then (result)->
				expect(result).not.to.equal(fileContent)
				`var require,module;`
				eval(result)
				expect(typeof blankReturn).to.equal 'undefined'
				delete require
				delete module



		test.skip "NPM modules can be imported by their package name reference", ()->
			fs.writeAsync(tempFile('npmImporter.js'), "
				var units = import 'timeunits'
			").then ()->
				SimplyImport("import test/temp/npmImporter.js", {preventGlobalLeaks:false}, {isStream:true}).then (result)->
					eval(result)
					expect(typeof units).to.equal 'object'
					expect(units.hour).to.equal 3600000



		test.skip "SimplyImport won't attempt to resolve an import as an NPM package if it starts with '/' or '../' or './'", ()->
			origLog = console.error
			console.error = chai.spy()
			
			fs.writeAsync(tempFile('npmImporter.js'), "
				var units = import './timeunits'
			").then ()->
				SimplyImport("import test/temp/npmImporter.js", null, {isStream:true})
					.then ()-> expect(true).to.be.false # Shouldn't execute
					.catch (err)->
						expect(err).to.be.an.error; if err.constructor is chai.AssertionError then throw err
						expect(console.error).to.have.been.called.exactly(1)
						console.error = origLog



		test.skip "Supplied file path will first attempt to resolve to NPM module path and only upon failure will it proceed to resolve to a local file", ()->
			Promise.all([
				fs.writeAsync tempFile('npmImporter.js'), "var units = import 'timeunits'"
				fs.writeAsync tempFile('timeunits.js'), "module.exports = 'localFile'"
			]).then ()->
				SimplyImport("import test/temp/npmImporter.js", {preventGlobalLeaks:false}, {isStream:true}).then (result)->
					eval(result)
					expect(typeof units).to.equal 'object'
					expect(units.hour).to.equal 3600000
					
					Promise.all([
						fs.writeAsync tempFile('npmFailedImporter.js'), "var units = import 'timeunits2'"
						fs.writeAsync tempFile('timeunits2.js'), "module.exports = 'localFile'"
					]).then ()->
						SimplyImport("import test/temp/npmFailedImporter.js", {preventGlobalLeaks:false}, {isStream:true}).then (result)->
							eval(result)
							expect(typeof units).to.equal 'string'
							expect(units).to.equal 'localFile'



		test.skip "Core node globals will be polyfilled", ()->
			fileContent = "
				global.env = process.env;
				global.dir = __dirname;
				global.file = __filename;
				global.globalRef = global;
			"
			SimplyImport(fileContent, null, {isStream:true}).then (result)->
				expect(result).not.to.equal(fileContent)
				eval(result)
				expect(typeof env).to.equal 'object'
				expect(env).to.eql {}
				expect(dir).to.equal '/'
				expect(file).to.equal '/main.js'
				expect(globalRef).to.equal global
				delete env
				delete dir
				delete file
				delete globalRef
				
				SimplyImport('outer.env = process.env', null, {isStream:true}).then (result)->
					outer = {}
					eval(result)
					expect(outer.env).to.exist
					expect(typeof outer.env).to.equal 'object'
					expect(outer.env).to.eql {}




		test.skip "The global process variable will not be polyfilled if it is declared in the code or if it is explicitly imported", ()->
			fileContent = "
				var process = {env:null};
				this.env = process.env;
			"
			SimplyImport(fileContent, null, {isStream:true}).then (result)->
				expect(result).to.equal(fileContent)
				eval(result)
				expect(env).to.equal null
				delete env
				
				fileContent = "
					var theProcess = require('process');
					this.env = theProcess.env;
				"
				SimplyImport(fileContent, null, {isStream:true}).then (result)->
					expect(result).not.to.equal(fileContent)
					expect(result).not.to.include('var process = require')
					eval(result)
					expect(typeof env).to.equal 'object'
					expect(env).to.eql {}
					delete env



		test.skip "Unsupported Core NPM modules won't be imported", ()->
			fileContent = "
				var fs = require('fs');
				var child_process = require('child_process');
				var cluster = require('cluster');
				var dgram = require('dgram');
				var dns = require('dns');
				var module = require('module');
				var net = require('net');
				var readline = require('readline');
				var repl = require('repl');
				var tls = require('tls');
			"
			SimplyImport(fileContent, null, {isStream:true}).then (result)->
				expect(result).to.equal(fileContent)



		test.skip "Supported core NPM modules will be imported as polyfills", ()-> if badES6Support then @skip() else
			testTitle = @_runnable.title
			fileContent = "
				global.assertB = import 'assert';\n\
				global.consoleB = import 'console';\n\
				global.constantsB = import 'constants';\n\
				global.cryptoB = import 'crypto';\n\
				global.domainB = import 'domain';\n\
				global.eventsB = import 'events';\n\
				global.httpB = import 'http';\n\
				global.httpsB = import 'https';\n\
				global.osB = import 'os';\n\
				global.pathB = import 'path';\n\
				global.processB = import 'process';\n\
				global.punycodeB = import 'punycode';\n\
				global.querystringB = import 'querystring';\n\
				global.string_decoderB = import 'string_decoder';\n\
				global.bufferB = import 'buffer';\n\
				global.timersB = import 'timers';\n\
				global.ttyB = import 'tty';\n\
				global.urlB = import 'url';\n\
				global.utilB = import 'util';\n\
				global.vmB = import 'vm';\n\
				global.zlibB = import 'zlib';\n\
			"
			global.XMLHttpRequest = ()-> {open:()->}
			importAndRunAsScript(fileContent, 'core-NPM-module-polyfills.js').timeout(5000)
				.then (result)->
					expect(result).not.to.equal(fileContent)
					expect(typeof assertB.deepEqual).to.equal 'function'
					expect(typeof consoleB.log).to.equal 'function'
					expect(typeof constantsB).to.equal 'object'
					expect(typeof cryptoB.pbkdf2).to.equal 'function'
					expect(typeof domainB.create).to.equal 'function'
					expect(typeof eventsB).to.equal 'function'
					expect(typeof httpB.get).to.equal 'function'
					expect(typeof httpsB.get).to.equal 'function'
					expect(typeof osB.hostname).to.equal 'function'
					expect(typeof pathB.resolve).to.equal 'function'
					expect(typeof processB.cwd).to.equal 'function'
					expect(typeof punycodeB.decode).to.equal 'function'
					expect(typeof querystringB.encode).to.equal 'function'
					expect(typeof string_decoderB.StringDecoder).to.equal 'function'
					expect(typeof bufferB.Buffer).to.equal 'function'
					expect(typeof timersB.setTimeout).to.equal 'function'
					expect(typeof ttyB.isatty).to.equal 'function'
					expect(typeof urlB.parse).to.equal 'function'
					expect(typeof utilB.inspect).to.equal 'function'
					expect(typeof vmB.Script).to.equal 'function'
					expect(typeof zlibB.createGzip).to.equal 'function'

				.catch Promise.TimeoutError , ()->
					console.error chalk.bgYellow.white('WARNING')+" The test '#{testTitle}' has timed out due to an unknown error..."



		test.skip "Cyclic imports are supported", ()->
			Promise.all([
				fs.writeAsync tempFile('importer.js'), "var fileA = import 'fileA.js'\nvar fileB = import 'fileB.js'\nvar fileC = import 'fileC.js'"
				fs.writeAsync tempFile('importerSingle.js'), "var fileA = import 'fileA.js'\nvar fileA2 = import 'fileA.js'"
				fs.writeAsync tempFile('fileA.js'), "var theOtherOne = import 'fileB.js';\n var thisOne = 'fileA-'+theOtherOne"
				fs.writeAsync tempFile('fileB.js'), "var theOtherOne = import 'fileA.js';\n var thisOne = 'fileB-'+theOtherOne"
				fs.writeAsync tempFile('fileC.js'), "module.exports = import 'fileD.js';"
				fs.writeAsync tempFile('fileD.js'), "import 'fileA.js';"
			]).then ()->
				SimplyImport("import test/temp/importer.js", {preventGlobalLeaks:false}, {isStream:true}).then (result)->
					try
						eval(result)
						expect(fileA).to.equal 'fileA-fileB-[object Object]'
						expect(fileB).to.equal 'fileB-[object Object]'
						expect(fileC).to.equal 'fileA-fileB-[object Object]'
					catch err
						console.log(result)
						throw err
					
					SimplyImport("import test/temp/importerSingle.js", {preventGlobalLeaks:false}, {isStream:true}).then (result)->
						eval(result)
						expect(fileA).to.equal('fileA-fileB-[object Object]')



		test.skip "Self imports are supported", ()->
			fs.writeAsync(tempFile('selfImporter.js'), "module.exports = {name:'thySelf'};\nprocess.nextTick(()=> exports.selfRef = import 'selfImporter.js')").then ()->
				SimplyImport('var data = import test/temp/selfImporter.js', {preventGlobalLeaks:false}, {isStream:true}).then (result)->
					eval(result)
					process.nextTick ()->
						expect(typeof data).to.equal 'object'
						expect(data.name).to.equal 'thySelf'
						expect(data.selfRef).to.equal data




		test.skip "If the imported file is a browserified package, its require/export statements won't be touched", ()->
			Browserify(Streamify("require('timeunits');")).bundleAsync().then (browserified)->
				Promise.all([
					fs.writeAsync tempFile('browserifyImporter.js'), "var units = import 'browserified.js'"
					fs.writeAsync tempFile('browserified.js'), browserified
				]).then ()->
					SimplyImport("import test/temp/browserifyImporter.js", {preventGlobalLeaks:false}, {isStream:true}).then (result)->
						# console.log result
						eval(result)
						expect(result).to.include("require('timeunits');")
						expect(typeof units).to.equal 'object'
						# units = units('timeunits')
						# expect(units.hour).to.equal 3600000



		test.skip "Transforms (browserify-style) can be applied to the bundled package", ()->
			fs.writeAsync(tempFile('es6.js'), "let abc = 123;").then ()->
				SimplyImport('import test/temp/es6.js', null, isStream:true).then (result)->
					expect(result).to.include('let abc')
					expect(result).not.to.include('var abc')
					
					SimplyImport('import test/temp/es6.js', {transform:['babelify', {presets:'es2015-script', sourceMaps:false}]}, isStream:true).then (result)->
						expect(result).not.to.include('let abc')
						expect(result).to.include('var abc')



		test.skip "Multiple transforms can be applied in a chain by providing an array of transforms", ()->
			Promise.all([
				fs.writeAsync tempFile('es6.js'), "let abc = 123;"
				fs.copyAsync path.join('test','helpers','node_modules','coffeeify'), 'node_modules/coffeeify'
			]).then ()->					
				SimplyImport('import test/temp/es6.js', {transform:['coffeeify', ['babelify', {presets:'es2015-script', sourceMaps:false}]]}, {isStream:true, isCoffee:true}).then (result)->
					expect(result).not.to.include('let abc')
					expect(result).to.include('var abc')



		test.skip "Invalid transforms will throw an error", ()->
			fs.writeAsync(tempFile('es6.js'), "let abc = 123;").then ()->
				SimplyImport('import test/temp/es6.js', {transform:['coffeeify', []]}, {isStream:true, isCoffee:true})
					.then ()-> expect(true).to.be.false # Shouldn't execute
					.catch (err)->
						expect(err).to.be.an.error;
						if err.constructor is chai.AssertionError then throw err



		test.skip "Global transforms can be applied to all imported files except for the main file", ()->
			Promise.all([
				fs.writeAsync(tempFile('fileA.js'), "let abc = 123;")
				fs.writeAsync(tempFile('fileB.js'), "let def = 456;")
				fs.writeAsync(tempFile('importer.js'), "import fileA.js\nimport fileB.js\nlet ghi = 789;")
			]).then ()->
				SimplyImport(tempFile('importer.js'), {globalTransform:[require('./helpers/uppercaseTransform'), path.join 'test','helpers','spacerTransform.coffee']}).then (result)->
					resultLines = result.split('\n')
					expect(resultLines[0]).to.equal('L E T   A B C   =   1 2 3 ;')
					expect(resultLines[1]).to.equal('L E T   D E F   =   4 5 6 ;')
					expect(resultLines[2]).to.equal('let ghi = 789;')



		test.skip "File specific options can be passed options.fileSpecific or through the 'simplyimport' field in package.json", ()->
			Promise.all([
				fs.writeAsync(tempFile('fileA.js'), "let abc = 123;")
				fs.writeAsync(tempFile('fileB.js'), "let DeF = 456;\nrequire('fileC.js')")
				fs.writeAsync(tempFile('fileC.js'), "let ghi = 789;")
				fs.writeAsync(tempFile('importer.js'), "import fileA.js\nimport fileB.js")
			]).then ()->
				opts = 
					globalTransform: require('./helpers/uppercaseTransform')
					fileSpecific:
						'*fileA.js':
							transform: path.resolve('test','helpers','spacerTransform')
						
						"fileB.js":
							transform: path.resolve('test','helpers','lowercaseTransform.coffee')
							scan: false
				
				SimplyImport(tempFile('importer.js'), opts).then (result)->
					resultLines = result.split('\n')
					expect(resultLines[0]).to.equal('L E T   A B C   =   1 2 3 ;')
					expect(resultLines[1]).to.equal('let def = 456;')
					expect(resultLines[2]).to.equal('require(\'filec.js\')')

					
					fs.writeAsync(tempFile('module','package.json'), JSON.stringify(simplyimport:opts.fileSpecific)).then ()->
						new Promise (done)->
							cliOpts = {cwd:path.resolve('test','temp','module')}
							cliTransform = path.resolve('test','helpers','uppercaseTransform')
							cliInput = path.resolve tempFile('importer.js')
							
							exec "#{bin} -i #{cliInput} -g #{cliTransform}", cliOpts, (err, resultFromCLI, stderr)->
								throw err if err
								throw new Error(stderr) if stderr
								expect(resultFromCLI).to.equal(result)
								done()


		test.skip "File paths will be included as comments in the first line of module export functions unless options.includePathComments is off", ()->
			Promise.resolve()
				.then ()->
					Promise.all [
						fs.writeAsync tempFile('fileA.js'), 'module.exports = "fileA"'
						fs.writeAsync tempFile('fileB.js'), 'module.exports = "fileB"'
						fs.writeAsync tempFile('importer.js'), '
							var A1 = import "./fileA";\n\
							var A2 = require("./fileA");\n\
							var A3 = require("./fileB");
						'
					]

				.then ()->
					SimplyImport(tempFile('importer.js'), includePathComments:true).then (result)->
						expect(result).to.contain('// test/temp/fileA.js')
						expect(result).to.contain('// test/temp/fileB.js')
				
				.then ()->
					SimplyImport(tempFile('importer.js'), includePathComments:false).then (result)->
						expect(result).not.to.contain('// test/temp/fileA.js')
						expect(result).not.to.contain('// test/temp/fileB.js')







	suite "CoffeeScript", ()->
		test.skip "Imported files will be detected as Coffeescript-type if their extension is '.coffee'", ()->
			fs.writeAsync(tempFile('a.coffee'), "import someFile.js").then ()->
				SimplyImport(tempFile('a.coffee')).then (result)->
					expect(result).to.equal "`abc123`"



		test.skip "Passing state {isCoffee:true} will cause it to be treated as a Coffeescript file even if its extension isn't '.coffee'", ()->
			fs.writeAsync(tempFile('a.js'), "import someFile.js").then ()->
				SimplyImport(tempFile('a.js'), null, {isCoffee:true}).then (result)->
					expect(result).to.equal "`abc123`"



		test.skip "If no extension is provided for an import and the importing parent is a Coffee file then the import will be treated as a Coffee file", ()->
			fs.writeAsync(tempFile('varDec.coffee'), "abc = 50").then ()->
				SimplyImport("import test/temp/varDec", null, {isStream:true, isCoffee:true}).then (result)->
					expect(result).to.equal "abc = 50"


		test.skip "If an extension-less import is treated as a Coffee file but doesn't exist, SimplyImport will attempt treat it as a JS file", ()->
			SimplyImport("import test/temp/someFile", null, {isStream:true, isCoffee:true}).then (result)->
				expect(result).to.equal "`abc123`"



		test.skip "If an importer is a JS file attempting to import a Coffee file, the Coffee file will be compiled to JS", ()->
			fs.writeAsync(tempFile('varDec.coffee'), "abc = 50").then ()->
				SimplyImport("import test/temp/varDec", {compileCoffeeChildren:true}, {isStream:true}).then (result)->
					expect(result).to.equal "var abc;\n\nabc = 50;\n"



		test.skip "When a Coffee file imports a JS file, single-line comments shouldn't be removed", ()->
			fs.writeAsync(tempFile('commented.js'), "// var abc = 50;").then ()->
				SimplyImport("import 'test/temp/commented.js'", null, {isCoffee:true, isStream:true}).then (result)->
					expect(result).to.contain "// var abc = 50;"



		test.skip "When a Coffee file imports a JS file, all the backticks in the JS file will be escaped", ()->
			fs.writeAsync(tempFile('js-with-backticks.js'), "
				var abc = '`123``';\n// abc `123` `
			").then ()->
				SimplyImport("import 'test/temp/js-with-backticks.js'", null, {isCoffee:true, isStream:true}).then (result)->
					expect(result).to.equal "`var abc = '\\`123\\`\\`';\n// abc \\`123\\` \\``"



		test.skip "Backtick escaping algorithm doesn't escape pre-escaped backticks", ()->
			fs.writeAsync(tempFile('js-with-escaped-backticks.js'), "
				var abc = '`123\\``';\n// abc `123\\` `
			").then ()->
				SimplyImport("import 'test/temp/js-with-escaped-backticks.js'", null, {isCoffee:true, isStream:true}).then (result)->
					expect(result).to.equal "`var abc = '\\`123\\`\\`';\n// abc \\`123\\` \\``"



		test.skip "When a Coffee file imports a JS file, escaped newlines should be removed", ()->
			fs.writeAsync(tempFile('newline-escaped.js'), "
				multiLineTrick = 'start \\\n
				middle \\\n
				end \\\n
				'
			").then ()->
				SimplyImport("import 'test/temp/newline-escaped.js'", null, {isCoffee:true, isStream:true}).then (result)->
					expect(result).to.equal "`multiLineTrick = 'start  middle  end  '`"



		test.skip "If spacing exists before the import statement, that whitespace will be appended to each line of the imported file", ()->
			fs.writeAsync(tempFile('tabbed.coffee'), "
				if true\n\ta = 1\n\tb = 2
			").then ()->
				SimplyImport("\t\timport 'test/temp/tabbed.coffee'", null, {isCoffee:true, isStream:true}).then (result)->
					resultLines = result.split '\n'
					expect(resultLines[0]).to.equal '\t\tif true'
					expect(resultLines[1]).to.equal '\t\t\ta = 1'
					expect(resultLines[2]).to.equal '\t\t\tb = 2'



		test.skip "When a JS file attempts to import a Coffee file while options.compileCoffeeChildren is off will cause an error to be thrown", ()->
			fs.writeAsync(tempFile('variable.coffee'), "'Imported variable';").then ()->
				SimplyImport("import 'test/temp/variable.coffee'", null, {isStream:true})
					.then ()-> expect(true).to.be.false # Shouldn't execute
					.catch (err)-> expect(err).to.be.an.error; if err.constructor is chai.AssertionError then throw err



		test.skip "Duplicate imports will cause the entry to be wrapped in a IIFE", ()->
			fs.writeAsync(tempFile('variable.coffee'), "output = 'someOutput'").then ()->
				importDec = "import 'test/temp/variable.coffee'"
				SimplyImport("#{importDec}\n#{importDec}\n", null, {isStream:true, isCoffee:true}).then (result)->
					expect(result).not.to.equal "var output = 'someOutput'\n var output = 'someOutput'\n"
					result = coffeeCompiler.compile result, 'bare':true
					result = result.replace /\_s\$m\(\d+\)/g, (entire)-> "invokeFn(#{entire})"

					invokeCount = 0
					invokeFn = (result)->
						invokeCount++
						expect(result).to.equal 'someOutput'

					eval(result)
					expect(invokeCount).to.equal 2



		test.skip "Duplicate imports references will be used even for duplicates across multiple files", ()->
			Promise.all([
				fs.writeAsync(tempFile('variable.coffee'), "output = 'someOutput'")
				fs.writeAsync(tempFile('importingB.coffee'), "import variable.coffee")
				fs.writeAsync(tempFile('importingA.coffee'), "import variable.coffee")
			]).then ()->				
				SimplyImport("import 'test/temp/importingA.coffee'\nimport 'test/temp/importingB.coffee'\nimport 'test/temp/variable.coffee'", null, {isStream:true, isCoffee:true}).then (result)->
					result = do ()->
						partA = result.split('\n').slice(0,5).join('\n')
						partB = result.split('\n').slice(5).join('\n')
						partA+'\n'+partB.replace /\_s\$m\(\d+\)/g, (entire)-> "invokeFn(#{entire})"

					result = coffeeCompiler.compile result, 'bare':true

					invokeCount = 0
					invokeFn = (result)->
						invokeCount++
						expect(result).to.equal 'someOutput'
					
					eval(result)
					expect(invokeCount).to.equal 3



		test.skip "Duplicate imports of VanillaJS files should cause the duplicate references have backticks wrapped around them", ()->
			fs.writeAsync(tempFile('jsFile.js'), "var jsFn = function(){return 42;}").then ()->
				SimplyImport("import test/temp/jsFile\nimport test/temp/jsFile", null, {isStream:true, isCoffee:true}).then (result)->
					try
						resultValue = eval(coffeeCompiler.compile result, 'bare':true)
					catch err
						console.error(result)
						throw err
					
					expect(typeof resultValue).to.equal 'function'
					expect(resultValue()).to.equal(42)




		test.skip "Imports can have exports (ES6 syntax) and they can be imported via ES6 syntax", ()->
			opts = {preventGlobalLeaks:false}
			fs.writeAsync(tempFile('exportBasic.coffee'), "
				AAA = 'aaa'; BBB = 'bbb'; CCC = 'ccc'; DDD = 'ddd';\n\
				export {AAA, BBB,CCC as ccc,  DDD as DDDDD  }\n\
				export default ()-> 33\n\
				export namedFn = ()-> 33\n\
				export class someClass\n\
				export another = 'anotherValue'\n\
				export kid ='kiddy';
			").then ()->
				SimplyImport("import myDefault, { AAA,BBB, ccc as CCC,DDDDD as ddd,kid,  kiddy, another} from test/temp/exportBasic.coffee", opts, {isStream:true, isCoffee:true}).then (result)->
					eval(result = coffeeCompiler.compile result, 'bare':true)
					expect(AAA).to.equal 'aaa'
					expect(BBB).to.equal 'bbb'
					expect(ddd).to.equal 'ddd'
					expect(kid).to.equal 'kiddy'
					expect(kiddy).to.equal undefined
					expect(another).to.equal 'anotherValue'
					expect(myDefault()).to.equal 33
					delete AAA
					delete BBB
					delete ddd
					delete kid
					delete kiddy
					delete another
					delete myDefault

					SimplyImport("import test/temp/exportBasic.coffee", opts, {isStream:true, isCoffee:true}).then (result)->
						eval(result = coffeeCompiler.compile result, 'bare':true)
						expect(()-> AAA).to.throw()
						expect(()-> BBB).to.throw()
						expect(()-> ddd).to.throw()
						expect(()-> kid).to.throw()
						expect(()-> kiddy).to.throw()
						expect(()-> another).to.throw()

						SimplyImport("import {BBB} from test/temp/exportBasic.coffee\nimport {kid} from test/temp/exportBasic.coffee", opts, {isStream:true, isCoffee:true}).then (result)->
							eval(result = coffeeCompiler.compile result, 'bare':true)
							expect(BBB).to.equal 'bbb'
							expect(kid).to.equal 'kiddy'
							delete BBB
							delete kid

							SimplyImport("import defFn from test/temp/exportBasic.coffee\nimport defFnAlias from test/temp/exportBasic.coffee", opts, {isStream:true, isCoffee:true}).then (result)->
								eval(result = coffeeCompiler.compile result, 'bare':true)
								expect(defFn()).to.equal 33
								expect(defFnAlias()).to.equal 33
								delete defFn
								delete defFnAlias

								SimplyImport("import * as allExports from test/temp/exportBasic.coffee", opts, {isStream:true, isCoffee:true}).then (result)->
									eval(result = coffeeCompiler.compile result, 'bare':true)
									expect(typeof allExports).to.equal 'object'
									expect(allExports.AAA).to.equal 'aaa'
									expect(allExports.DDDDD).to.equal 'ddd'
									expect(allExports.namedFn()).to.equal 33
									expect(typeof allExports.someClass).to.equal 'function'
									expect(allExports['*default*']()).to.equal 33
									delete allExports

									Promise.all([
										SimplyImport("import * as allA from test/temp/exportBasic.coffee", opts, {isStream:true, isCoffee:true})
										SimplyImport("allB = import test/temp/exportBasic.coffee", opts, {isStream:true, isCoffee:true})
									]).then (results)->
										results = results.map (result)-> coffeeCompiler.compile result, 'bare':true
										eval(results[0])
										eval(results[1])
										expect(allA).to.exist
										expect(allB).to.exist
										expect(allA.AAA).to.equal(allB.AAA)
										expect(allA.BBB).to.equal(allB.BBB)
										expect(allA.ddd).to.equal(allB.ddd)
										expect(allA.kid).to.equal(allB.kid)
										expect(allA.kiddy).to.equal(allB.kiddy)
										expect(allA.another).to.equal(allB.another)
										expect(allA.namedFn()).to.equal(allB.namedFn())
										expect(allA['*default*']()).to.equal(allB['*default*']())



		test.skip "CoffeeScript-forbidden keywords can be used in ES6 exports", ()->
			fs.writeAsync(tempFile('exportForbidden.coffee'), "
				AAA = 'aaa'; BBB = 'bbb'; CCC = 'ccc'; DDD = 'ddd';\n\
				export var AAA = 'aaa';\n\
				export let BBB = 'bbb';\n\
				export const CCC = 'ccc';\n\
				export class someClass\n\
				export another = 'anotherValue'
			").then ()->
				SimplyImport("import * as @forbiddenExports from test/temp/exportForbidden.coffee", null, {isStream:true, isCoffee:true}).then (result)->
					eval(result = coffeeCompiler.compile result, 'bare':true)
					expect(typeof forbiddenExports).to.equal 'object'
					expect(forbiddenExports.AAA).to.equal 'aaa'
					expect(forbiddenExports.BBB).to.equal 'bbb'
					expect(forbiddenExports.CCC).to.equal 'ccc'
					expect(forbiddenExports.another).to.equal 'anotherValue'
					expect(typeof forbiddenExports.someClass).to.equal 'function'




		test.skip "Imports can have exports (CommonJS syntax) and they can be imported via ES6 syntax", ()->
			opts = {preventGlobalLeaks:false}
			fs.writeAsync(tempFile('exportBasic.coffee'), "
				AAA = 'aaa'; BBB = 'bbb'; CCC = 'ccc'; DDD = 'ddd';\n\
				exports = module.exports = ()-> 33\n\
				module.exports.AAA = AAA\n\
				module.exports[BBB.toUpperCase()] = BBB\n\
				moduleExports = exports\n\
				moduleExports[\"kid\"] = 'kiddy'\n\
				EEE = 'eee'; exports['CCC'] = CCC\n\
				module.exports.DDDDD = DDD\n\
				exports.another = 'anotherValue'\n\
			").then ()->
				SimplyImport("import { AAA,BBB, ccc as CCC,DDDDD as ddd,kid,  kiddy, another} from test/temp/exportBasic.coffee", opts, {isStream:true, isCoffee:true}).then (result)->
					eval(result = coffeeCompiler.compile result, 'bare':true)
					expect(AAA).to.equal 'aaa'
					expect(BBB).to.equal 'bbb'
					expect(ddd).to.equal 'ddd'
					expect(kid).to.equal 'kiddy'
					expect(kiddy).to.equal undefined
					expect(another).to.equal 'anotherValue'
					delete AAA
					delete BBB
					delete ddd
					delete kid
					delete kiddy
					delete another
					
					SimplyImport("import test/temp/exportBasic.coffee", opts, {isStream:true, isCoffee:true}).then (result)->
						eval(result = coffeeCompiler.compile result, 'bare':true)
						expect(()-> AAA).to.throw()
						expect(()-> BBB).to.throw()
						expect(()-> ddd).to.throw()
						expect(()-> kid).to.throw()
						expect(()-> kiddy).to.throw()
						expect(()-> another).to.throw()
					
						SimplyImport("import {BBB} from test/temp/exportBasic.coffee\nimport {kid} from test/temp/exportBasic.coffee", opts, {isStream:true, isCoffee:true}).then (result)->
							eval(result = coffeeCompiler.compile result, 'bare':true)
							expect(BBB).to.equal 'bbb'
							expect(kid).to.equal 'kiddy'
							delete BBB
							delete kid
										
							SimplyImport("import * as allExports from test/temp/exportBasic.coffee", opts, {isStream:true, isCoffee:true}).then (result)->
								eval(result = coffeeCompiler.compile result, 'bare':true)
								expect(typeof allExports).to.equal 'function'
								expect(allExports()).to.equal 33
								expect(allExports.AAA).to.equal 'aaa'
								expect(allExports.DDDDD).to.equal 'ddd'
								delete allExports
										
								SimplyImport("fetchedAAA = (import test/temp/exportBasic.coffee).AAA", opts, {isStream:true, isCoffee:true}).then (result)->
									eval(result = coffeeCompiler.compile result, 'bare':true)
									expect(fetchedAAA).to.equal 'aaa'
									delete fetchedAAA


									Promise.all([
										SimplyImport("import * as allA from test/temp/exportBasic.coffee", opts, {isStream:true, isCoffee:true})
										SimplyImport("allB = import test/temp/exportBasic.coffee", opts, {isStream:true, isCoffee:true})
									]).then (results)->
										results = results.map (result)-> coffeeCompiler.compile result, 'bare':true
										eval(results[0])
										eval(results[1])
										expect(allA).to.exist
										expect(allB).to.exist
										expect(allA.AAA).to.equal(allB.AAA)
										expect(allA.BBB).to.equal(allB.BBB)
										expect(allA.ddd).to.equal(allB.ddd)
										expect(allA.kid).to.equal(allB.kid)
										expect(allA.kiddy).to.equal(allB.kiddy)
										expect(allA.another).to.equal(allB.another)
										expect(allA()).to.equal(allB())



		test.skip "CommonJS syntax imports will behave exactly the same as ES6 imports", ()->
			importLines = [
				"import 'withquotes.coffee'"
				"import 'withext.coffee'"
				"import 'noext'"
				"import 'realNoExt'"
				"import 'nested/nested1.coffee'"
				"import 'dir'"
				"variable = import 'variable.coffee'"
				"\# import 'commented.coffee'"
			]
			requireLines = importLines.map (dec)-> dec.replace('import', 'require')
			requireLines[1] = requireLines[1].replace /require (.+)/, 'require($1)'

			Promise.all([
				fs.writeAsync(tempFile('withquotes.coffee'), 'withquotes')
				fs.writeAsync(tempFile('withext.coffee'), 'withext')
				fs.writeAsync(tempFile('noext.coffee'), 'noext')
				fs.writeAsync(tempFile('realNoExt'), 'realNoExt')
				fs.writeAsync(tempFile('nested', 'nested1.coffee'), 'nested')
				fs.writeAsync(tempFile('dir/index.coffee'), 'dir')
				fs.writeAsync(tempFile('variable.coffee'), 'variable')
			]).then ()->
				Promise.all([
					SimplyImport(importLines.join('\n'), null, {isStream:true, isCoffee:true, context:'test/temp'})
					SimplyImport(requireLines.join('\n'), null, {isStream:true, isCoffee:true, context:'test/temp'})
				]).then (results)->
					expect(results[0].split('\n').slice(0,-2)).to.eql(results[1].split('\n').slice(0,-2))
					Promise.all [
						fs.removeAsync(tempFile('noext.coffee'))
						fs.removeAsync(tempFile('realNoExt'))
						fs.removeAsync(tempFile('dir'))
					]



		test.skip "NPM modules can be imported by their package name reference", ()->
			fs.writeAsync(tempFile('npmImporter.coffee'), "
				units = import 'timeunits'
			").then ()->
				SimplyImport("import test/temp/npmImporter.coffee", {preventGlobalLeaks:false}, {isStream:true, isCoffee:true}).then (result)->
					eval(result = coffeeCompiler.compile result, 'bare':true)
					expect(typeof units).to.equal 'object'
					expect(units.hour).to.equal 3600000



		test.skip "Supplied file path will first attempt to resolve to NPM module path and only upon failure will it proceed to resolve to a local file", ()->
			Promise.all([
				fs.writeAsync tempFile('npmImporter.coffee'), "units = import 'timeunits'"
				fs.writeAsync tempFile('timeunits.coffee'), "module.exports = 'localFile'"
			]).then ()->
				SimplyImport("import test/temp/npmImporter.coffee", {preventGlobalLeaks:false}, {isStream:true, isCoffee:true}).then (result)->
					eval(result = coffeeCompiler.compile result, 'bare':true)
					expect(typeof units).to.equal 'object'
					expect(units.hour).to.equal 3600000
					
					Promise.all([
						fs.writeAsync tempFile('npmFailedImporter.coffee'), "units = import 'timeunits2'"
						fs.writeAsync tempFile('timeunits2.coffee'), "module.exports = 'localFile'"
					]).then ()->
						SimplyImport("import test/temp/npmFailedImporter.coffee", {preventGlobalLeaks:false}, {isStream:true, isCoffee:true}).then (result)->
							eval(result = coffeeCompiler.compile result, 'bare':true)
							expect(typeof units).to.equal 'string'
							expect(units).to.equal 'localFile'




		test.skip "Core node globals will be polyfilled", ()->
			fileContent = "
				@env = process.env\n\
				@dir = __dirname\n\
				@file = __filename\n\
				@globalRef = global\n\
			"
			SimplyImport(fileContent, null, {isStream:true, isCoffee:true}).then (result)->
				expect(result).not.to.equal(fileContent)
				eval(result = coffeeCompiler.compile result, 'bare':true)
				expect(typeof env).to.equal 'object'
				expect(env).to.eql {}
				expect(dir).to.equal '/'
				expect(file).to.equal '/main.js'
				expect(globalRef).to.equal global
				delete env
				delete dir
				delete file
				delete globalRef
				
				SimplyImport('outer.env = process.env', null, {isStream:true, isCoffee:true}).then (result)->
					outer = {}
					eval(result = coffeeCompiler.compile result, 'bare':true)
					expect(outer.env).to.exist
					expect(typeof outer.env).to.equal 'object'
					expect(outer.env).to.eql {}


		test.skip "When wrapping coffee content in a closure, a fat arrow will be used only if there is a usage of the 'this' or '@' keyword", ()->
			Promise.all([
				fs.writeAsync tempFile('thisKeywordYesA.coffee'), "inner = 123\nthis.exported = inner;"
				fs.writeAsync tempFile('thisKeywordYesB.coffee'), "inner = 456\n@exported = inner;"
				fs.writeAsync tempFile('thisKeywordNo.coffee'), "inner = 678\nmod.exported = inner;"
				fs.writeAsync tempFile('thisImporter.coffee'), "importA = import './thisKeywordYesA'\nimportB = import './thisKeywordYesB'\nimportC = import './thisKeywordNo'"
			]).then ()->
				SimplyImport(tempFile 'thisImporter.coffee').then (result)->
					expect(result).to.contain "importA = do ()=>"
					expect(result).to.contain "importB = do ()=>"
					expect(result).to.contain "importC = do ()->"


		test.skip "Import statements with prior content should only be wrapped in an IIFE if it has more than 1 statement or if it has invalid syntax + more than 1 line", ()->
			Promise.all([
				fs.writeAsync tempFile('iifeYesA.coffee'), "inner = 123; exported = inner;"
				fs.writeAsync tempFile('iifeYesB.coffee'), "inner = 123\nexported = inner;"
				fs.writeAsync tempFile('iifeErrorA.coffee'), "var inner = 456\nvar outer = 123"
				fs.writeAsync tempFile('iifeErrorB.coffee'), "var inner = 456"
				fs.writeAsync tempFile('iifeNo.coffee'), "inner = 456"
				fs.writeAsync tempFile('iifeImporter.coffee'), "importA = import './iifeYesA'\nimportB = import './iifeYesB'\nimportC = import './iifeErrorA'\nimportD = import './iifeErrorB'\nimportE = import './iifeNo'"
			]).then ()->
				SimplyImport(tempFile 'iifeImporter.coffee').then (result)->
					expect(result).to.contain "importA = do ()->"
					expect(result).to.contain "importB = do ()->"
					expect(result).to.contain "importC = do ()->"
					expect(result).to.contain "importD = var inner = 456"
					expect(result).to.contain "importE = inner = 456"


		test.skip "File paths will be included as comments in the first line of module export functions unless options.includePathComments is off", ()->
			Promise.resolve()
				.then ()->
					Promise.all [
						fs.writeAsync tempFile('fileA.coffee'), 'module.exports = "fileA"'
						fs.writeAsync tempFile('fileB.coffee'), 'module.exports = "fileB"'
						fs.writeAsync tempFile('importer.coffee'), '
							A1 = import "./fileA";\n\
							A2 = require "./fileA";\n\
							A3 = require "./fileB";
						'
					]

				.then ()->
					SimplyImport(tempFile('importer.coffee'), includePathComments:true).then (result)->
						expect(result).to.contain('# test/temp/fileA.coffee')
						expect(result).to.contain('# test/temp/fileB.coffee')
				
				.then ()->
					SimplyImport(tempFile('importer.coffee'), includePathComments:false).then (result)->
						expect(result).not.to.contain('# test/temp/fileA.coffee')
						expect(result).not.to.contain('# test/temp/fileB.coffee')










	suite "Conditions", ()->
		test.skip "An array of conditions can be stated between the 'import' word and file path to test against the provided conditions list during compilation", ()->
			importDec = "import [condA] 'test/temp/someFile.js'"
			SimplyImport(importDec, {preserve:true}, {isStream:true}).then (result)->
				expect(result).to.equal "// #{importDec}"
				
				SimplyImport(importDec, {conditions:['condA']}, {isStream:true}).then (result)->
					expect(result).to.equal "abc123"


		test.skip "All conditions must be satisfied in order for the file to be imported", ()->
			importDec = "import [condA, condB] 'test/temp/someFile.js'"
			SimplyImport(importDec, {conditions:['condA'], preserve:true}, {isStream:true}).then (result)->
				expect(result).to.equal "// #{importDec}"
				
				SimplyImport(importDec, {conditions:['condA', 'condB', 'condC']}, {isStream:true}).then (result)->
					expect(result).to.equal "abc123"


		test.skip "If the provided condition (to satisfy) matches ['*'], all conditions will be passed", ()->
			importDec = "import [condA, condB] 'test/temp/someFile.js'"
			SimplyImport(importDec, {conditions:['condA'], preserve:true}, {isStream:true}).then (result)->
				expect(result).to.equal "// #{importDec}"
				
				SimplyImport(importDec, {conditions:'*'}, {isStream:true}).then (result)->
					expect(result).to.equal "abc123"





	suite ".scanImports()", ()->
		importerLines = [
			"import 'withquotes.js'"
			"import noquotes.js"
			"import 'withext.js'"
			"import 'noext'"
			"import 'realNoExt'"
			"import 'nested/nested1.js'"
			"import 'dir'"
			""
			"variable = import 'variable.js'"
			"// import 'commented.js'"
		]
		importer = importerLines.join('\n')

		suiteSetup ()-> Promise.all [
			fs.writeAsync(tempFile('importer.js'), importer)
			fs.writeAsync(tempFile('withquotes.js'), 'withquotes')
			fs.writeAsync(tempFile('noquotes.js'), 'noquotes')
			fs.writeAsync(tempFile('withext.js'), 'withext')
			fs.writeAsync(tempFile('noext.js'), 'noext')
			fs.writeAsync(tempFile('realNoExt'), 'realNoExt')
			fs.writeAsync(tempFile('nested', 'nested1.js'), 'nested')
			fs.writeAsync(tempFile('dir/index.js'), 'dir')
			fs.writeAsync(tempFile('variable.js'), 'variable')
		]

		test.skip "Calling SimplyImport.scanImports(path) will retrieve import objects for all discovered imports in a file", ()->
			Promise.props(
				imports: SimplyImport.scanImports('test/temp/importer.js')
				importsFromStream: SimplyImport.scanImports importer, {isStream:true, context:'test/temp/'}
			).then ({imports, importsFromStream})->
				expect(imports.length).to.equal 8
				expect(imports[0].path).to.equal 'withquotes.js'
				expect(imports[1].path).to.equal 'noquotes.js'
				expect(imports[2].path).to.equal 'withext.js'
				expect(imports[3].path).to.equal 'noext.js'
				expect(imports[4].path).to.equal 'realNoExt'
				expect(imports[5].path).to.equal 'nested/nested1.js'
				expect(imports[6].path).to.equal 'dir/index.js'
				expect(imports[7].path).to.equal 'variable.js'
				expect(imports).eql importsFromStream



		test.skip "Specifying an options object of {pathOnly:true} will retrieve the file paths of all discovered imports in a file", ()->
			Promise.props(
				imports: SimplyImport.scanImports('test/temp/importer.js', pathOnly:true)
				importsFromStream: SimplyImport.scanImports importer, {isStream:true, context:'test/temp/', pathOnly:true}
			).then ({imports, importsFromStream})->
				expect(imports.length).to.equal 8
				expect(imports[0]).to.equal 'withquotes.js'
				expect(imports[1]).to.equal 'noquotes.js'
				expect(imports[2]).to.equal 'withext.js'
				expect(imports[3]).to.equal 'noext.js'
				expect(imports[4]).to.equal 'realNoExt'
				expect(imports[5]).to.equal 'nested/nested1.js'
				expect(imports[6]).to.equal 'dir/index.js'
				expect(imports[7]).to.equal 'variable.js'
				expect(imports).eql importsFromStream



		test.skip "Specifying an options object of {pathOnly:true, withContext:true} will retrieve absolute file paths of all discovered imports in a file", ()->
			SimplyImport.scanImports('test/temp/importer.js', {pathOnly:true, withContext:true}).then (imports)->
				context = path.join __dirname,'temp'
				
				expect(imports.length).to.equal 8
				expect(imports[0]).to.equal path.join(context, 'withquotes.js')
				expect(imports[1]).to.equal path.join(context, 'noquotes.js')
				expect(imports[2]).to.equal path.join(context, 'withext.js')
				expect(imports[3]).to.equal path.join(context, 'noext.js')
				expect(imports[4]).to.equal path.join(context, 'realNoExt')
				expect(imports[5]).to.equal path.join(context, 'nested/nested1.js')
				expect(imports[6]).to.equal path.join(context, 'dir/index.js')
				expect(imports[7]).to.equal path.join(context, 'variable.js')




		test.skip "Specifying an options object of {isStream:true, pathOnly:true} will assume that the first argument is the contents of the file", ()->
			SimplyImport.scanImports('import someFile.js', {isStream:true, pathOnly:true, context:'test/temp'}).then (imports)->
				expect(imports.length).to.equal 1
				expect(imports[0]).to.equal 'someFile.js'




		test.skip "Specifying an options object of {isStream:true} and not indicating the context will default the context to process.cwd()", ()->
			SimplyImport.scanImports('import test/temp/someFile.js', {isStream:true, pathOnly:true}).then (imports)->
				expect(imports.length).to.equal 1
				expect(imports[0]).to.equal 'test/temp/someFile.js'



		test.skip "Passing state {isCoffee:true} will cause it to be treated as a Coffeescript file even if its extension isn't '.coffee'", ()->
			fs.writeAsync(tempFile('b.js'), "import someFile.js\n\# import anotherFile.js").then ()->
				SimplyImport.scanImports(tempFile('b.js'), {isCoffee:true, pathOnly:true}).then (result)->
					expect(result[0]).to.equal "someFile.js"



		test.skip "Passing files that import nonexistent files shall not reject promises and should just skip the nonexistent ones", ()->
			imports = [
				"import 'test/temp/someFile.js'"
				"import 'test/temp/doesntExist.js'"
				"import 'test/temp/someFile2.js'"
			]
			SimplyImport.scanImports(imports.join('\n'), {isStream:true, isCoffee:true, pathOnly:true}).then (result)->
				expect(result.length).to.equal 2
				expect(result[0]).to.equal 'test/temp/someFile.js'
				expect(result[1]).to.equal 'test/temp/someFile2.js'





	suite "General", ()->			
		test.skip "Failed imports will be kept in a commented-out form if options.preserve is set to true", ()->
			fs.writeAsync(tempFile('failedImport.js'), '123').then ()->
				importDec = "import [abc] 'test/temp/failedImport.js'"
			
				SimplyImport(importDec, {preserve:true}, {isStream:true}).then (result)->
					expect(result).to.equal "// #{importDec}"
			
					SimplyImport(importDec, null, {isStream:true}).then (result)->
						expect(result).to.equal "{}"
			
						fs.writeAsync(tempFile('failedImport.coffee'), '123').then ()->
							importDec = "import [abc] 'test/temp/failedImport.coffee'"
						
							SimplyImport(importDec, {preserve:true}, {isStream:true, isCoffee:true}).then (result)->
								expect(result).to.equal "\# #{importDec}"



		test.skip "Importing a nonexistent file will cause the import process to be halted/rejected", ()->
			origLog = console.error
			console.error = chai.spy()
			
			SimplyImport("import 'test/temp/nonexistent'", null, {isStream:true})
				.then ()-> expect(true).to.be.false # Shouldn't execute
				.catch (err)->
					expect(err).to.be.an.error; if err.constructor is chai.AssertionError then throw err
					
					fs.dirAsync(tempFile('dirNoIndex')).then ()->
						SimplyImport("import 'test/temp/dirNoIndex'", null, {isStream:true})
							.then ()-> expect(true).to.be.false # Shouldn't execute
							.catch (err)->
								expect(err).to.be.an.error; if err.constructor is chai.AssertionError then throw err
								expect(console.error).to.have.been.called.exactly(2)
								console.error = origLog



		test.skip "Providing SimplyImport with an invalid input path will cause an error to be thrown", ()->
			SimplyImport('test/temp/nonexistent.js')
				.then ()-> expect(true).to.be.false # Shouldn't execute
				.catch (err)-> expect(err).to.be.an.error; if err.constructor is chai.AssertionError then throw err



		test.skip "If output path is a directory, the result will be written to the a file with the same name as the input file appended with .compiled at the end", ()->
			Promise.all([
				fs.writeAsync(tempFile('childFile.js'), 'abc123')
				fs.writeAsync(tempFile('theFile.js'), "import 'childFile.js'")
		
			]).then ()-> new Promise (resolve)->
				exec "#{bin} -i #{tempFile('theFile.js')} -o #{tempFile('output')} -s -p", (err, stdout, stderr)->
					throw err if err
					result = null
					expect ()-> result = fs.readFileSync tempFile('output', 'theFile.compiled.js'), {encoding:'utf8'}
						.not.to.throw()
					
					expect(result).to.equal 'abc123'
					resolve()



		test.skip "If output path is a directory, an input path must be provided", (done)->
			exec "echo 'whatever' | #{bin} -o test/", (err, stdout, stderr)->
				expect(err).to.be.an 'error'
				done()



		test.skip "Imports within imports should not be resolved if options.recursive is set to false", ()->
			fs.writeAsync(tempFile('nestedA.js'), "A\nimport 'nestedB.js'").then ()->
				fs.writeAsync(tempFile('nestedB.js'), "B").then ()->
					
					SimplyImport("import 'test/temp/nestedA.js'", {recursive:false}, {isStream:true}).then (result)->
						expect(result).to.equal "A\nimport 'nestedB.js'"



		test.skip "if options.dirCache is true then cached dir listings will be used in file path resolving", ()->
			opts = {isStream:true, pathOnly:true, context:path.join(__dirname,'../')}
			SimplyImport.defaults.dirCache = true
			
			SimplyImport.scanImports("import test/temp/someFile", opts).then (result)->
				expect(result[0]).to.equal "test/temp/someFile.js"
				
				fs.writeAsync(tempFile('dirWithIndex', 'index.js'), 'abc123').then ()->
					SimplyImport("import test/temp/dirWithIndex", opts)
						.then (result)-> expect(true).to.be.false # Shouldn't execute
						.catch (err)->
							expect(err).to.be.an.error; if err.constructor is chai.AssertionError then throw err
							SimplyImport.defaults.dirCache = false
			
							SimplyImport.scanImports("import test/temp/dirWithIndex", opts).then (result)->
								expect(result[0]).to.equal "test/temp/dirWithIndex/index.js"



		test.skip "Quoted import/require statements will be ignored", ()->
			fileContent = "var ignored = 'this require(\'statement\') will be ignored'"
			SimplyImport(fileContent, null, {isStream:true}).then (result)->
				expect(result).to.equal(fileContent)
				
				fileContent = "var ignored = 'this statment will also be ignored import statement2'"
				SimplyImport(fileContent, null, {isStream:true}).then (result)->
					expect(result).to.equal(fileContent)



		test.skip "Import paths can be provided without a file extension", ()->
			SimplyImport("import test/temp/someFile", null, {isStream:true}).then (result)->
				expect(result).to.equal "abc123"
				
				fs.writeAsync(tempFile('extraExtension.min.js'), "def456").then ()->
					SimplyImport("import test/temp/extraExtension.min", null, {isStream:true}).then (result)->
						expect(result).to.equal "def456"


		test.skip "Certain imports can be ignored by having them be surrounded by opening and closing 'simplyimport:ignore' comments", ()->
			Promise.all([
				fs.writeAsync tempFile('fileA.js'), '"theFileA"'
				fs.writeAsync tempFile('fileB.js'), '"theFileB"'
				fs.writeAsync tempFile('importer.js'), "
					A = import './fileA'\n\
					B = require('./fileB')\n\
					
					// simplyimport:ignore\n\
					C = import './fileA'\n\
					D = require('./fileB')\n\
					// simplyimport:ignore\n\
					
					E = import './fileA'\n\
					
					// simplyimport:ignore\n\
					F = require('./fileB')\n\
					// simplyimport:ignore\n\
					
					G = require('./fileB')\n\
					
					// simplyimport:ignore\n\
					H = import './fileA'\n\
					I = require('./fileB')\n\
				"
			]).then ()->
				SimplyImport(tempFile('importer.js')).then (result)->
					expect(result).not.to.contain	'A = import'
					expect(result).not.to.contain	'B = require'
					expect(result).to.contain		'C = import'
					expect(result).to.contain		'D = require'
					expect(result).not.to.contain	'E = import'
					expect(result).to.contain		'F = require'
					expect(result).not.to.contain	'G = require'
					expect(result).to.contain		'H = import'
					expect(result).to.contain		'I = require'



		test.skip "Importing module packages should also respect their browserify.transform field", ()->
			Promise.resolve()
				.then ()->
					helpers.createModule
						dest: tempFile('samplemodule')
						body: 'var abc=123;\nvar def = require("imported-module")'
						replaceBody: true

				.tap (sampleModulePath)->
					helpers.createModule(
						dest: path.resolve sampleModulePath,'node_modules','imported-module'
						json:
							'name': 'imported-module'
							'main': 'app.coffee'
							'browserify': 'transform': ['coffeeify', {'sourceMap':false}]
						modules: [
							path.resolve('test','helpers','node_modules','coffeeify')
						]
						body: '(a,b)-> a*b'
						replaceBody: true
					).then (subModule)-> fs.moveAsync(path.join(subModule,'index.js'), path.join(subModule,'app.coffee'))
				
				.then (sampleModulePath)-> SimplyImport(path.resolve(sampleModulePath,'index.js'))
				.then (result)->
					expect(result).to.contain('var abc=123')
					expect(result).to.contain('var def = ')
					expect(result).not.to.contain('(a,b)->')
					
					eval(result)
					expect(abc).to.equal(123)
					expect(typeof def).to.equal('function')
					expect(def(8,12)).to.equal(96)
				.then ()-> fs.removeAsync tempFile('samplemodule')



		test.skip "The simplyimportify transformer and invalid transforms will be skipped if exists on a module's browserify.transform field", ()->
			Promise.resolve()
				.then ()->
					helpers.createModule
						dest: tempFile('samplemodule')
						body: 'var abc=123;\nimport "imported-module"'
						replaceBody: true

				.tap (sampleModulePath)->
					helpers.createModule(
						dest: path.resolve sampleModulePath,'node_modules','imported-module'
						json:
							'name': 'imported-module'
							'main': 'app.coffee'
							'browserify': 'transform': [
								'simplyimportify'
								['coffeeify', {'sourceMap':false}]
							]
						modules: [
							path.resolve('test','helpers','node_modules','coffeeify')
						]
						files:
							'fn.coffee': '(a,b)-> (a*b)*b'
						body: 'def = import "./fn"'
						replaceBody: true
					).then (subModule)-> fs.moveAsync(path.join(subModule,'index.js'), path.join(subModule,'app.coffee')).catch ()->
				
				.then (sampleModulePath)-> SimplyImport(path.resolve(sampleModulePath,'index.js'))
				.then (result)->
					expect(result).to.contain('var abc=123')
					expect(result).to.contain('var def')
					expect(result).to.contain('def = function')
					expect(result).not.to.contain('(a,b)->')
					
					eval(result)
					expect(abc).to.equal(123)
					expect(typeof def).to.equal('function')
					expect(def(8,12)).to.equal(8*12*12)
				.then ()-> fs.removeAsync tempFile('samplemodule')



		test.skip "Mappings in a module's package.json browser field will be respected", ()->
			Promise.resolve()
				.then ()->
					helpers.createModule
						dest: tempFile('samplemodule')
						files:
							'index.js': 'var samplemodule="node";\nvar ignored=import "ignored-module"\nimport "imported-module"'
							'index-browser.js': 'var samplemodule="browser";\nvar ignored=import "ignored-module"\nimport "imported-module"'
						json:
							'browser':
								'ignored-module': false
								'./index.js': './index-browser.js'

				.tap (sampleModulePath)->
					helpers.createModule
						dest: path.resolve sampleModulePath,'node_modules','imported-module'
						json:
							'name': 'imported-module'
							'browser':
								'./inner-ignored.js': false
								'./inner-ignored2.js': false
								'./index.js': './index-browser.js'
						
						files:
							'index.js': 'var importedmodule="node";\nvar innerignored=import "inner-ignored"'
							'index-browser.js': 'var importedmodule="browser";\nvar innerignored=import "inner-ignored"\nvar innerignored2=import "./inner-ignored.js"'
							'inner-ignored.js': 'module.exports = "NOT IGNORED"'

				.tap (sampleModulePath)->
					helpers.createModule
						dest: path.resolve sampleModulePath,'node_modules','ignored-module'
						json: 'name': 'ignored-module'						

				
				.then (sampleModulePath)-> SimplyImport(path.resolve(sampleModulePath,'index.js'))
				.then (result)->
					eval(result)
					expect(samplemodule).to.equal 'browser'
					expect(importedmodule).to.equal 'browser'
					expect(ignored).to.eql {}
					expect(innerignored).to.eql {}
					expect(innerignored2).to.eql {}
				.then ()-> fs.removeAsync tempFile('samplemodule')



		test.skip "Non-javascript files can be imported", ()->
			Promise.resolve()
				.then ()-> fs.writeAsync tempFile('sample.html'), '<div>innerText</div>'
				.then ()->
					SimplyImport("var html = require('#{tempFile('sample.html')}')", null, isStream:true).then (result)->
						expect(result).to.contain('var html = <div>innerText</div>')



		suite "Commented imports won't be imported", ()->
			test.skip "JS Syntax", ()->
				importDec = "// import 'test/desc/withquotes.js'"
				SimplyImport(importDec, null, {isStream:true}).then (result)->
					expect(result).to.equal importDec
			
			test.skip "CoffeeScript Syntax", ()->
				importDec = "# import 'test/desc/withquotes.js'"
				SimplyImport(importDec, null, {isStream:true, isCoffee:true}).then (result)->
					expect(result).to.equal importDec
			
			test.skip "DocBlock Syntax", ()->
				importDec = "* import 'test/desc/withquotes.js'"
				SimplyImport(importDec, null, {isStream:true}).then (result)->
					expect(result).to.equal importDec






































