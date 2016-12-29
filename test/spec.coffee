Promise = require 'bluebird'
fs = Promise.promisifyAll require 'fs-extra'
path = require 'path'
chai = require 'chai'
chaiSpies = require 'chai-spies'
chai.use chaiSpies
expect = chai.expect
should = chai.should()
coffeeCompiler = require 'coffee-script'
Streamify = require 'streamify-string'
Browserify = require 'browserify'
Browserify::bundleAsync = Promise.promisify(Browserify::bundle)
regEx = require '../lib/regex'
exec = require('child_process').exec
bin = path.join '.', 'bin'

if process.env.forCoverage
	SimplyImport = require '../forCoverage/simplyimport.js'
else
	SimplyImport = require '../index.js'

SimplyImport.defaults.dirCache = false


Promise.config longStackTraces:true

tempFile = (fileNames...)->
	path.join 'test','temp',path.join.apply(path, fileNames)
			# fs.outputFileAsync(tempFile('nestedA.js'), "A").then ()->
			# 	SimplyImport("import 'test/temp/nestedA.js'", null, {isStream:true}).then (result)->
			# 		expect(result).to.equal "A"
			

suite "SimplyImport", ()->
	suiteTeardown ()-> fs.removeAsync(path.join 'test','temp')
	suiteSetup ()-> fs.ensureDirAsync(path.join 'test','temp','output').then ()-> fs.outputFileAsync(path.join('test','temp','someFile.js'), 'abc123')





	suite "General", ()->
		test "Failed imports will be kept in a commented-out form if options.preserve is set to true", ()->
			fs.outputFileAsync(tempFile('failedImport.js'), '123').then ()->
				importDec = "import [abc] 'test/temp/failedImport.js'"
			
				SimplyImport(importDec, {preserve:true}, {isStream:true}).then (result)->
					expect(result).to.equal "// #{importDec}"
			
					SimplyImport(importDec, null, {isStream:true}).then (result)->
						expect(result).to.equal ""
			

					fs.outputFileAsync(tempFile('failedImport.coffee'), '123').then ()->
						importDec = "import [abc] 'test/temp/failedImport.coffee'"
					
						SimplyImport(importDec, {preserve:true}, {isStream:true, isCoffee:true}).then (result)->
							expect(result).to.equal "\# #{importDec}"



		test "Importing a nonexistent file will cause the import process to be halted/rejected", ()->
			origLog = console.error
			console.error = chai.spy()
			
			SimplyImport("import 'test/temp/nonexistent'", null, {isStream:true})
				.then ()-> expect(true).to.be.false # Shouldn't execute
				.catch (err)->
					expect(err).to.be.an.error; if err.constructor is chai.AssertionError then throw err
					
					fs.ensureDirAsync(tempFile('dirNoIndex')).then ()->
						SimplyImport("import 'test/temp/dirNoIndex'", null, {isStream:true})
							.then ()-> expect(true).to.be.false # Shouldn't execute
							.catch (err)->
								expect(err).to.be.an.error; if err.constructor is chai.AssertionError then throw err
								expect(console.error).to.have.been.called.exactly(2)
								console.error = origLog



		test "Providing SimplyImport with an invalid input path will cause an error to be thrown", ()->
			SimplyImport('test/temp/nonexistent.js')
				.then ()-> expect(true).to.be.false # Shouldn't execute
				.catch (err)-> expect(err).to.be.an.error; if err.constructor is chai.AssertionError then throw err



		test "If output path is a directory, the result will be written to the a file with the same name as the input file appended with .compiled at the end", ()->			
			Promise.all([
				fs.outputFileAsync(tempFile('childFile.js'), 'abc123')
				fs.outputFileAsync(tempFile('theFile.js'), "import 'childFile.js'")
		
			]).then ()-> new Promise (resolve)->
				exec "#{bin} -i #{tempFile('theFile.js')} -o #{tempFile('output')} -s -p", (err, stdout, stderr)->
					throw err if err
					result = null
					expect ()-> result = fs.readFileSync tempFile('output', 'theFile.compiled.js'), {encoding:'utf8'}
						.not.to.throw()
					
					expect(result).to.equal 'abc123'
					resolve()



		test "If output path is a directory, an input path must be provided", (done)->
			exec "echo 'whatever' | #{bin} -o test/", (err, stdout, stderr)->
				expect(err).to.be.an 'error'
				done()



		test "Imports within imports should not be resolved if options.recursive is set to false", ()->
			fs.outputFileAsync(tempFile('nestedA.js'), "A\nimport 'nestedB.js'").then ()->
				fs.outputFileAsync(tempFile('nestedB.js'), "B").then ()->
					
					SimplyImport("import 'test/temp/nestedA.js'", {recursive:false}, {isStream:true}).then (result)->
						expect(result).to.equal "A\nimport 'nestedB.js'"



		test "if options.dirCache is true then cached dir listings will be used in file path resolving", ()->
			origLog = console.error
			console.error = chai.spy()
			opts = {isStream:true, pathOnly:true, context:path.join(__dirname,'../')}
			SimplyImport.defaults.dirCache = true
			
			SimplyImport.scanImports("import test/temp/someFile", opts).then (result)->
				expect(result[0]).to.equal "test/temp/someFile.js"
				
				fs.outputFileAsync(tempFile('dirWithIndex', 'index.js'), 'abc123').then ()->
					SimplyImport.scanImports("import test/temp/dirWithIndex", opts)
						.then (result)-> expect(true).to.be.false # Shouldn't execute
						.catch (err)->
							expect(err).to.be.an.error; if err.constructor is chai.AssertionError then throw err
							SimplyImport.defaults.dirCache = false
			
							SimplyImport.scanImports("import test/temp/dirWithIndex", opts).then (result)->
								expect(result[0]).to.equal "test/temp/dirWithIndex/index.js"
								expect(console.error).to.have.been.called.exactly(1)
								console.error = origLog



		suite "Commented imports won't be imported", ()->
			test "JS Syntax", ()->
				importDec = "// import 'test/desc/withquotes.js'"
				SimplyImport(importDec, null, {isStream:true}).then (result)->
					expect(result).to.equal importDec
			
			test "CoffeeScript Syntax", ()->
				importDec = "# import 'test/desc/withquotes.js'"
				SimplyImport(importDec, null, {isStream:true, isCoffee:true}).then (result)->
					expect(result).to.equal importDec
			
			test "DocBlock Syntax", ()->
				importDec = "* import 'test/desc/withquotes.js'"
				SimplyImport(importDec, null, {isStream:true}).then (result)->
					expect(result).to.equal importDec


			





	suite "VanillaJS", ()->
		test "Imports will be minified if options.uglify is set", ()->
			fs.outputFileAsync(tempFile('uglify-subject.js'), "
				if (a) {
					var abc = true;
				} else {
					var abc = false;
				}
			").then ()->
				SimplyImport("import 'test/temp/uglify-subject.js'", {uglify:true}, {isStream:true}).then (result)->
					expect(result).to.equal "if(a)var abc=!0;else var abc=!1;"



		test "Unquoted imports that have whitespace after them should not make any difference", ()->
			SimplyImport("import test/temp/someFile.js\t", null, {isStream:true}).then (result)->
				expect(result).to.equal "abc123\t"
			


		test "Imports surrounded by parentheses should not make any difference", ()->
			fs.outputFileAsync(tempFile('string.js'), "'abc123def'").then ()->
				SimplyImport("var varResult = (import test/temp/string.js).toUpperCase()", null, {isStream:true}).then (result)->
					eval(result)
					expect(varResult).to.equal "ABC123DEF"
					
					SimplyImport("(import test/temp/string.js).toUpperCase()", null, {isStream:true}).then (result)->
						expect(eval(result)).to.equal "ABC123DEF"
					
						SimplyImport(" (import test/temp/string.js).toUpperCase()", null, {isStream:true}).then (result)->
							expect(eval(result)).to.equal "ABC123DEF"



		test "Imports can end with a semicolon", ()->
			fs.outputFileAsync(tempFile('string.js'), "'abc123def'").then ()->
				SimplyImport("import test/temp/string.js;", null, {isStream:true}).then (result)->
					expect(result).to.equal "'abc123def'"



		test "An import statement can be placed after preceding content", ()->
			SimplyImport("var imported = import test/temp/someFile.js", null, {isStream:true}).then (result)->
				expect(result).to.equal "var imported = abc123"



		test "Duplicate imports will cause the imported file to be wrapped in an IIFE and have its last statement returned with all imports referencing the return value", ()->
			invokeCount = 0
			expectation = null
			invokeFn = (result)->
				invokeCount++
				expect(result).to.equal expectation

			adjustResult = (result, lines)->
				result
					.split '\n'
					.map (line, index)-> if lines.includes(index) then line.replace(/(\_sim\_.{5})/, 'invokeFn($1)') else line
					.join '\n'

			fs.outputFileAsync(tempFile('fileA.js'), "output = 'varLess'").then ()->
				SimplyImport("import 'test/temp/fileA.js'\n".repeat(2), null, {isStream:true}).then (result)->
					expect(result.startsWith "var output = 'varLess'").to.be.false

					expectation = 'varLess'
					eval(adjustResult(result, [1,2]))
					expect(invokeCount).to.equal 2

					fs.outputFileAsync(tempFile('fileB.js'), "var output = 'withVar'").then ()->
						SimplyImport("import 'test/temp/fileB.js'\n".repeat(2), null, {isStream:true}).then (result)->
							expect(result.startsWith "var output = 'withVar'").to.be.false

							expectation = 'withVar'
							eval(adjustResult(result, [2,3]))
							expect(invokeCount).to.equal 4

						fs.outputFileAsync(tempFile('fileC.js'), "return 'returnStatment'").then ()->
							SimplyImport("import 'test/temp/fileC.js'\n".repeat(2), null, {isStream:true}).then (result)->
								expect(result.startsWith "return 'returnStatment'").to.be.false

								expectation = 'returnStatment'
								eval(adjustResult(result, [1,2]))
								expect(invokeCount).to.equal 6

								fs.outputFileAsync(tempFile('fileD.js'), "if (true) {output = 'condA'} else {output = 'condB'}").then ()->
									SimplyImport("import 'test/temp/fileD.js'\n".repeat(2), null, {isStream:true}).then (result)->
										expect(result.startsWith "if (true)").to.be.false

										expectation = undefined
										eval(adjustResult(result, [1,2]))
										expect(invokeCount).to.equal 8

										origLog = console.error
										console.error = chai.spy()
										fs.outputFileAsync(tempFile('fileE.js'), "var 123 = 'invalid syntax'").then ()->
											SimplyImport("import 'test/temp/fileE.js'\n".repeat(2), null, {isStream:true}).then (result)->
												expect(console.error).to.have.been.called.exactly(1)
												console.error = origLog



		test "Duplicate imports references will be used even for duplicates across multiple files", ()->
			Promise.all([
				fs.outputFileAsync(tempFile('variable.js'), "output = 'someOutput'")
				fs.outputFileAsync(tempFile('importingB.js'), "import variable.js")
				fs.outputFileAsync(tempFile('importingA.js'), "import variable.js")
			]).then ()->				
				SimplyImport("import 'test/temp/importingA.js'\nimport 'test/temp/importingB.js'\nimport 'test/temp/variable.js'", null, {isStream:true}).then (result)->
					origResult = result
					result = result
						.split '\n'
						.map (line, index)-> if [2,3,4].includes(index) then line.replace(/(\_sim\_.{5})/, 'invokeFn($1)') else line
						.join '\n'

					invokeCount = 0
					invokeFn = (result)->
						invokeCount++
						expect(result).to.equal 'someOutput'
					
					eval(result)
					expect(invokeCount).to.equal 3



		test "Imports can have exports (ES6 syntax) and they can be imported via ES6 syntax", ()->
			opts = {preventGlobalLeaks:false}
			fs.outputFileAsync(tempFile('exportBasic.js'), "
				var AAA = 'aaa', BBB = 'bbb', CCC = 'ccc', DDD = 'ddd';\n\
				export {AAA, BBB,CCC as ccc,  DDD as DDDDD  }\n\
				export default function(){return 33};\n\
				export function namedFn (){return 33};\n\
				export function namedFn2 = ()=> 33;\n\
				export class someClass {};\n\
				export var another = 'anotherValue'\n\
				export let kid ='kiddy';
			").then ()->
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
					
					SimplyImport("import test/temp/exportBasic.js", opts, {isStream:true}).then (result)->
						eval(result)
						expect(()-> AAA).to.throw()
						expect(()-> BBB).to.throw()
						expect(()-> ddd).to.throw()
						expect(()-> kid).to.throw()
						expect(()-> kiddy).to.throw()
						expect(()-> another).to.throw()
					
						SimplyImport("import {BBB} from test/temp/exportBasic.js\nimport {kid} from test/temp/exportBasic.js", opts, {isStream:true}).then (result)->
							eval(result)
							expect(BBB).to.equal 'bbb'
							expect(kid).to.equal 'kiddy'
							delete BBB
							delete kid
					
							SimplyImport("import defFn from test/temp/exportBasic.js\nimport defFnAlias from test/temp/exportBasic.js", opts, {isStream:true}).then (result)->
								eval(result)
								expect(defFn()).to.equal 33
								expect(defFnAlias()).to.equal 33
								delete defFn
								delete defFnAlias
					
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
										expect(allA.namedFn()).to.equal(allB.namedFn())
										expect(allA.namedFn2()).to.equal(allB.namedFn2())
										expect(allA['*default*']()).to.equal(allB['*default*']())



		test "Imports can have exports (CommonJS syntax) and they can be imported via ES6 syntax", ()->
			opts = {preventGlobalLeaks:false}
			fs.outputFileAsync(tempFile('exportBasic.js'), "
				var AAA = 'aaa', BBB = 'bbb', CCC = 'ccc', DDD = 'ddd';\n\
				exports = function(){return 33};\n\
				module.exports.AAA = AAA\n\
				module.exports[BBB.toUpperCase()] = BBB;\n\
				var moduleExports = exports;\n\
				moduleExports[\"kid\"] = 'kiddy'\n\
				var EEE = 'eee'; exports['CCC'] = CCC\n\
				module.exports.DDDDD = DDD;\n\
				exports.another = 'anotherValue';\n\
			").then ()->
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
					
					SimplyImport("import test/temp/exportBasic.js", opts, {isStream:true}).then (result)->
						eval(result)
						expect(()-> AAA).to.throw()
						expect(()-> BBB).to.throw()
						expect(()-> ddd).to.throw()
						expect(()-> kid).to.throw()
						expect(()-> kiddy).to.throw()
						expect(()-> another).to.throw()
					
						SimplyImport("import {BBB} from test/temp/exportBasic.js\nimport {kid} from test/temp/exportBasic.js", opts, {isStream:true}).then (result)->
							eval(result)
							expect(BBB).to.equal 'bbb'
							expect(kid).to.equal 'kiddy'
							delete BBB
							delete kid
										
							SimplyImport("import * as allExports from test/temp/exportBasic.js", opts, {isStream:true}).then (result)->
								eval(result)
								expect(typeof allExports).to.equal 'function'
								expect(allExports()).to.equal 33
								expect(allExports.AAA).to.equal 'aaa'
								expect(allExports.DDDDD).to.equal 'ddd'
								delete allExports


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



		test "CommonJS syntax imports will behave exactly the same as ES6 imports", ()->
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
				fs.outputFileAsync(tempFile('withquotes.js'), 'withquotes')
				fs.outputFileAsync(tempFile('withext.js'), 'withext')
				fs.outputFileAsync(tempFile('noext.js'), 'noext')
				fs.outputFileAsync(tempFile('realNoExt'), 'realNoExt')
				fs.outputFileAsync(tempFile('nested', 'nested1.js'), 'nested')
				fs.outputFileAsync(tempFile('dir/index.js'), 'dir')
				fs.outputFileAsync(tempFile('variable.js'), 'variable')
			]).then ()->
				Promise.all([
					SimplyImport(importLines.join('\n'), null, {isStream:true, context:'test/temp'})
					SimplyImport(requireLines.join('\n'), null, {isStream:true, context:'test/temp'})
				]).then (results)->
					expect(results[0].split('\n').slice(0,-1)).to.eql(results[1].split('\n').slice(0,-1))



		test "NPM modules can be imported by their package name reference", ()->
			fs.outputFileAsync(tempFile('npmImporter.js'), "
				var units = import 'timeunits'
			").then ()->
				SimplyImport("import test/temp/npmImporter.js", null, {isStream:true}).then (result)->
					eval(result)
					expect(typeof units).to.equal 'object'
					expect(units.hour).to.equal 3600000



		test "SimplyImport won't attempt to resolve an import as an NPM package if it starts with '/' or '../' or './'", ()->
			origLog = console.error
			console.error = chai.spy()
			
			fs.outputFileAsync(tempFile('npmImporter.js'), "
				var units = import './timeunits'
			").then ()->
				SimplyImport("import test/temp/npmImporter.js", null, {isStream:true})
					.then ()-> expect(true).to.be.false # Shouldn't execute
					.catch (err)->
						expect(err).to.be.an.error; if err.constructor is chai.AssertionError then throw err
						expect(console.error).to.have.been.called.exactly(1)
						console.error = origLog



		test "Supplied file path will first attempt to resolve to NPM module path and only upon failure will it proceed to resolve to a local file", ()->
			Promise.all([
				fs.outputFileAsync tempFile('npmImporter.js'), "var units = import 'timeunits'"
				fs.outputFileAsync tempFile('timeunits.js'), "module.exports = 'localFile'"
			]).then ()->
				SimplyImport("import test/temp/npmImporter.js", null, {isStream:true}).then (result)->
					eval(result)
					expect(typeof units).to.equal 'object'
					expect(units.hour).to.equal 3600000
					
					Promise.all([
						fs.outputFileAsync tempFile('npmFailedImporter.js'), "var units = import 'timeunits2'"
						fs.outputFileAsync tempFile('timeunits2.js'), "module.exports = 'localFile'"
					]).then ()->
						SimplyImport("import test/temp/npmFailedImporter.js", null, {isStream:true}).then (result)->
							eval(result)
							expect(typeof units).to.equal 'string'
							expect(units).to.equal 'localFile'



		test "If the imported file is a browserified package, its require/export statements won't be touched", ()->
			Browserify(Streamify("require('timeunits');")).bundleAsync().then (browserified)->
				Promise.all([
					fs.outputFileAsync tempFile('browserifyImporter.js'), "var units = import 'browserified.js'"
					fs.outputFileAsync tempFile('browserified.js'), browserified
				]).then ()->
					SimplyImport("import test/temp/browserifyImporter.js", null, {isStream:true}).then (result)->
						eval(result)
						expect(typeof units).to.equal 'function'
						units = units('timeunits')
						expect(units.hour).to.equal 3600000








	suite "CoffeeScript", ()->
		test "Imported files will be detected as Coffeescript-type if their extension is '.coffee'", ()->
			fs.outputFileAsync(tempFile('a.coffee'), "import someFile.js").then ()->
				SimplyImport(tempFile('a.coffee')).then (result)->
					expect(result).to.equal "`abc123`"



		test "Passing state {isCoffee:true} will cause it to be treated as a Coffeescript file even if its extension isn't '.coffee'", ()->
			fs.outputFileAsync(tempFile('a.js'), "import someFile.js").then ()->
				SimplyImport(tempFile('a.js'), null, {isCoffee:true}).then (result)->
					expect(result).to.equal "`abc123`"



		test "If no extension is provided for an import and the importing parent is a Coffee file then the import will be treated as a Coffee file", ()->
			fs.outputFileAsync(tempFile('varDec.coffee'), "abc = 50").then ()->
				SimplyImport("import test/temp/varDec", null, {isStream:true, isCoffee:true}).then (result)->
					expect(result).to.equal "abc = 50"
		


		test "If an extension-less import is treated as a Coffee file but doesn't exist, SimplyImport will attempt treat it as a JS file", ()->
			SimplyImport("import test/temp/someFile", null, {isStream:true, isCoffee:true}).then (result)->
				expect(result).to.equal "`abc123`"
			


		test "If an importer is a JS file attempting to import a Coffee file, the Coffee file will be compiled to JS", ()->
			fs.outputFileAsync(tempFile('varDec.coffee'), "abc = 50").then ()->
				SimplyImport("import test/temp/varDec", {compileCoffeeChildren:true}, {isStream:true}).then (result)->
					expect(result).to.equal "var abc;\n\nabc = 50;\n"



		test "When a Coffee file imports a JS file, single-line comments shouldn't be removed", ()->
			fs.outputFileAsync(tempFile('commented.js'), "// var abc = 50;").then ()->
				SimplyImport("import 'test/temp/commented.js'", null, {isCoffee:true, isStream:true}).then (result)->
					expect(result).to.contain "// var abc = 50;"



		test "When a Coffee file imports a JS file, all the backticks in the JS file will be escaped", ()->
			fs.outputFileAsync(tempFile('js-with-backticks.js'), "
				var abc = '`123``';\n// abc `123` `
			").then ()->
				SimplyImport("import 'test/temp/js-with-backticks.js'", null, {isCoffee:true, isStream:true}).then (result)->
					expect(result).to.equal "`var abc = '\\`123\\`\\`';\n// abc \\`123\\` \\``"



		test "Backtick escaping algorithm doesn't escape pre-escaped backticks", ()->
			fs.outputFileAsync(tempFile('js-with-escaped-backticks.js'), "
				var abc = '`123\\``';\n// abc `123\\` `
			").then ()->
				SimplyImport("import 'test/temp/js-with-escaped-backticks.js'", null, {isCoffee:true, isStream:true}).then (result)->
					expect(result).to.equal "`var abc = '\\`123\\`\\`';\n// abc \\`123\\` \\``"



		test "When a Coffee file imports a JS file, all DocBlocks' should be removed", ()->
			fs.outputFileAsync(tempFile('docblock.js'), "
				AAA;\n
				/* @preserve\n
				 * Copyright (c) 2013-2015 What Ever Name\n
				 */\n
				BBB;\n
				/**\n
				 * Additional data here\n
				 * bla bla bla\n
				*/\n
				CCC;
			").then ()->
				SimplyImport("import 'test/temp/docblock.js'", null, {isCoffee:true, isStream:true}).then (result)->
					expect(result).to.equal "`AAA;\n \n BBB;\n \n CCC;`"



		test "When a Coffee file imports a JS file, escaped newlines should be removed", ()->
			fs.outputFileAsync(tempFile('newline-escaped.js'), "
				multiLineTrick = 'start \\\n
				middle \\\n
				end \\\n
				'
			").then ()->
				SimplyImport("import 'test/temp/newline-escaped.js'", null, {isCoffee:true, isStream:true}).then (result)->
					expect(result).to.equal "`multiLineTrick = 'start  middle  end  '`"



		test "If spacing exists before the import statement, that whitespace will be appended to each line of the imported file", ()->
			fs.outputFileAsync(tempFile('tabbed.coffee'), "
				if true\n\ta = 1\n\tb = 2
			").then ()->
				SimplyImport("\t\timport 'test/temp/tabbed.coffee'", null, {isCoffee:true, isStream:true}).then (result)->
					resultLines = result.split '\n'
					expect(resultLines[0]).to.equal '\t\tif true'
					expect(resultLines[1]).to.equal '\t\t\ta = 1'
					expect(resultLines[2]).to.equal '\t\t\tb = 2'



		test "When a JS file attempts to import a Coffee file while options.compileCoffeeChildren is off will cause an error to be thrown", ()->
			fs.outputFileAsync(tempFile('variable.coffee'), "'Imported variable';").then ()->
				SimplyImport("import 'test/temp/variable.coffee'", null, {isStream:true})
					.then ()-> expect(true).to.be.false # Shouldn't execute
					.catch (err)-> expect(err).to.be.an.error; if err.constructor is chai.AssertionError then throw err



		test "Duplicate imports will cause the entry to be wrapped in a IIFE", ()->
			fs.outputFileAsync(tempFile('variable.coffee'), "output = 'someOutput'").then ()->
				importDec = "import 'test/temp/variable.coffee'"
				SimplyImport("#{importDec}\n #{importDec}\n", null, {isStream:true, isCoffee:true}).then (result)->
					expect(result).not.to.equal "var output = 'someOutput'\n var output = 'someOutput'\n"
					result = coffeeCompiler.compile result, 'bare':true
					result = result
						.split '\n'
						.map (line, index)-> if [7,8].includes(index) then line.replace(/(\_sim\_.+?);/, 'invokeFn($1);') else line
						.join '\n'

					invokeCount = 0
					invokeFn = (result)->
						invokeCount++
						expect(result).to.equal 'someOutput'

					eval(result)
					expect(invokeCount).to.equal 2



		test "Duplicate imports references will be used even for duplicates across multiple files", ()->
			Promise.all([
				fs.outputFileAsync(tempFile('variable.coffee'), "output = 'someOutput'")
				fs.outputFileAsync(tempFile('importingB.coffee'), "import variable.coffee")
				fs.outputFileAsync(tempFile('importingA.coffee'), "import variable.coffee")
			]).then ()->				
				SimplyImport("import 'test/temp/importingA.coffee'\nimport 'test/temp/importingB.coffee'\nimport 'test/temp/variable.coffee'", null, {isStream:true, isCoffee:true}).then (result)->
					result = result
						.split '\n'
						.map (line, index)-> if [7,8,9].includes(index) then line.replace(/(\_sim\_.{5})/, 'invokeFn($1)') else line
						.join '\n'
					result = coffeeCompiler.compile result, 'bare':true

					invokeCount = 0
					invokeFn = (result)->
						invokeCount++
						expect(result).to.equal 'someOutput'
					
					eval(result)
					expect(invokeCount).to.equal 3



		test "Imports can have exports (ES6 syntax) and they can be imported via ES6 syntax", ()->
			opts = {preventGlobalLeaks:false}
			fs.outputFileAsync(tempFile('exportBasic.coffee'), "
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



		test "Imports can have exports (CommonJS syntax) and they can be imported via ES6 syntax", ()->
			opts = {preventGlobalLeaks:false}
			fs.outputFileAsync(tempFile('exportBasic.coffee'), "
				AAA = 'aaa'; BBB = 'bbb'; CCC = 'ccc'; DDD = 'ddd';\n\
				exports = ()-> 33\n\
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



		test "CommonJS syntax imports will behave exactly the same as ES6 imports", ()->
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
				fs.outputFileAsync(tempFile('withquotes.coffee'), 'withquotes')
				fs.outputFileAsync(tempFile('withext.coffee'), 'withext')
				fs.outputFileAsync(tempFile('noext.coffee'), 'noext')
				fs.outputFileAsync(tempFile('realNoExt'), 'realNoExt')
				fs.outputFileAsync(tempFile('nested', 'nested1.coffee'), 'nested')
				fs.outputFileAsync(tempFile('dir/index.coffee'), 'dir')
				fs.outputFileAsync(tempFile('variable.coffee'), 'variable')
			]).then ()->
				Promise.all([
					SimplyImport(importLines.join('\n'), null, {isStream:true, isCoffee:true, context:'test/temp'})
					SimplyImport(requireLines.join('\n'), null, {isStream:true, isCoffee:true, context:'test/temp'})
				]).then (results)->
					expect(results[0].split('\n').slice(0,-1)).to.eql(results[1].split('\n').slice(0,-1))
					Promise.all [
						fs.removeAsync(tempFile('noext.coffee'))
						fs.removeAsync(tempFile('realNoExt'))
						fs.removeAsync(tempFile('dir'))
					]



		test "NPM modules can be imported by their package name reference", ()->
			fs.outputFileAsync(tempFile('npmImporter.coffee'), "
				units = import 'timeunits'
			").then ()->
				SimplyImport("import test/temp/npmImporter.coffee", null, {isStream:true, isCoffee:true}).then (result)->
					eval(result = coffeeCompiler.compile result, 'bare':true)
					expect(typeof units).to.equal 'object'
					expect(units.hour).to.equal 3600000



		test "Supplied file path will first attempt to resolve to NPM module path and only upon failure will it proceed to resolve to a local file", ()->
			Promise.all([
				fs.outputFileAsync tempFile('npmImporter.coffee'), "units = import 'timeunits'"
				fs.outputFileAsync tempFile('timeunits.coffee'), "module.exports = 'localFile'"
			]).then ()->
				SimplyImport("import test/temp/npmImporter.coffee", null, {isStream:true, isCoffee:true}).then (result)->
					eval(result = coffeeCompiler.compile result, 'bare':true)
					expect(typeof units).to.equal 'object'
					expect(units.hour).to.equal 3600000
					
					Promise.all([
						fs.outputFileAsync tempFile('npmFailedImporter.coffee'), "units = import 'timeunits2'"
						fs.outputFileAsync tempFile('timeunits2.coffee'), "module.exports = 'localFile'"
					]).then ()->
						SimplyImport("import test/temp/npmFailedImporter.coffee", null, {isStream:true, isCoffee:true}).then (result)->
							eval(result = coffeeCompiler.compile result, 'bare':true)
							expect(typeof units).to.equal 'string'
							expect(units).to.equal 'localFile'










	suite "Conditions", ()->
		test "An array of conditions can be stated between the 'import' word and file path to test against the provided conditions list during compilation", ()->
			importDec = "import [condA] 'test/temp/someFile.js'"
			SimplyImport(importDec, {preserve:true}, {isStream:true}).then (result)->
				expect(result).to.equal "// #{importDec}"
				
				SimplyImport(importDec, {conditions:['condA']}, {isStream:true}).then (result)->
					expect(result).to.equal "abc123"
		

		test "All conditions must be satisfied in order for the file to be imported", ()->
			importDec = "import [condA, condB] 'test/temp/someFile.js'"
			SimplyImport(importDec, {conditions:['condA'], preserve:true}, {isStream:true}).then (result)->
				expect(result).to.equal "// #{importDec}"
				
				SimplyImport(importDec, {conditions:['condA', 'condB', 'condC']}, {isStream:true}).then (result)->
					expect(result).to.equal "abc123"
		

		test "If the provided condition (to satisfy) matches ['*'], all conditions will be passed", ()->
			importDec = "import [condA, condB] 'test/temp/someFile.js'"
			SimplyImport(importDec, {conditions:['condA'], preserve:true}, {isStream:true}).then (result)->
				expect(result).to.equal "// #{importDec}"
				
				SimplyImport(importDec, {conditions:'*'}, {isStream:true}).then (result)->
					expect(result).to.equal "abc123"





	suite "API", ()->
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
			fs.outputFileAsync(tempFile('importer.js'), importer)
			fs.outputFileAsync(tempFile('withquotes.js'), 'withquotes')
			fs.outputFileAsync(tempFile('noquotes.js'), 'noquotes')
			fs.outputFileAsync(tempFile('withext.js'), 'withext')
			fs.outputFileAsync(tempFile('noext.js'), 'noext')
			fs.outputFileAsync(tempFile('realNoExt'), 'realNoExt')
			fs.outputFileAsync(tempFile('nested', 'nested1.js'), 'nested')
			fs.outputFileAsync(tempFile('dir/index.js'), 'dir')
			fs.outputFileAsync(tempFile('variable.js'), 'variable')
		]
		
		test "Calling SimplyImport.scanImports(path) will retrieve import objects for all discovered imports in a file", ()->
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



		test "Specifying an options object of {pathOnly:true} will retrieve the file paths of all discovered imports in a file", ()->
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



		test "Specifying an options object of {pathOnly:true, withContext:true} will retrieve absolute file paths of all discovered imports in a file", ()->
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
			



		test "Specifying an options object of {isStream:true, pathOnly:true} will assume that the first argument is the contents of the file", ()->
			SimplyImport.scanImports('import someFile.js', {isStream:true, pathOnly:true, context:'test/temp'}).then (imports)->
				expect(imports.length).to.equal 1
				expect(imports[0]).to.equal 'someFile.js'
			



		test "Specifying an options object of {isStream:true} and not indicating the context will default the context to process.cwd()", ()->
			SimplyImport.scanImports('import test/temp/someFile.js', {isStream:true, pathOnly:true}).then (imports)->
				expect(imports.length).to.equal 1
				expect(imports[0]).to.equal 'test/temp/someFile.js'



		test "Passing state {isCoffee:true} will cause it to be treated as a Coffeescript file even if its extension isn't '.coffee'", ()->
			fs.outputFileAsync(tempFile('b.js'), "import someFile.js\n\# import anotherFile.js").then ()->
				SimplyImport.scanImports(tempFile('b.js'), {isCoffee:true, pathOnly:true}).then (result)->
					expect(result[0]).to.equal "someFile.js"








































