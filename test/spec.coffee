Promise = require 'bluebird'
fs = Promise.promisifyAll require 'fs-extra'
path = require 'path'
chai = require 'chai'
chaiSpies = require 'chai-spies'
chai.use chaiSpies
expect = chai.expect
should = chai.should()
regEx = require '../lib/regex'
exec = require('child_process').exec
bin = path.join '.', 'bin'

if process.env.forCoverage
	SimplyImport = require '../forCoverage/simplyimport.js'
else
	SimplyImport = require '../index.js'

SimplyImport.defaults.dirCache = false

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
			
				SimplyImport(importDec, {silent:true, preserve:true}, {isStream:true}).then (result)->
					expect(result).to.equal "// #{importDec}"



		test "Importing a nonexistent file will cause the import process to be halted/rejected", ()->
			SimplyImport("import 'test/temp/nonexistent'", {silent:true, preserve:true}, {isStream:true})
				.then ()-> expect(true).to.be.false # Shouldn't execute
				.catch (err)-> expect(err).to.be.an.error



		test "Providing SimplyImport with an invalid input path will cause an error to be thrown", ()->
			SimplyImport('test/temp/nonexistent.js', {silent:true})
				.then ()-> expect(true).to.be.false # Shouldn't execute
				.catch (err)-> expect(err).to.be.an.error



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



		test "Imports within imports should not be resolved if options.recursive is set to false", ()->
			fs.outputFileAsync(tempFile('nestedA.js'), "A\nimport 'nestedB.js'").then ()->
				fs.outputFileAsync(tempFile('nestedB.js'), "B").then ()->
					
					SimplyImport("import 'test/temp/nestedA.js'", {recursive:false}, {isStream:true}).then (result)->
						expect(result).to.equal "A\nimport 'nestedB.js'"
			


		test "Unquoted imports that have whitespace after them should not make any difference", ()->
			SimplyImport("import test/temp/someFile.js\t", null, {isStream:true}).then (result)->
				expect(result).to.equal "abc123"


		test "An import statement can be placed after preceding content", ()->
			SimplyImport("var imported = import test/temp/someFile.js", null, {isStream:true}).then (result)->
				expect(result).to.equal "var imported = abc123"



		test "If a duplicate import exists it'll only be imported once and a reference to it will be used wherever imported", ()->
			fs.outputFileAsync(tempFile('variable.js'), "output = 'someOutput'").then ()->
				importDec = "import 'test/temp/variable.js'"
				SimplyImport("#{importDec}\n #{importDec}\n", null, {isStream:true}).then (result)->
					expect(result).not.to.equal "var output = 'someOutput'\n var output = 'someOutput'\n"
					result = result
						.split '\n'
						.map (line, index)-> if [2,3].includes(index) then "invokeFn(#{line});" else line
						.join '\n'

					invokeCount = 0
					invokeFn = (result)->
						invokeCount++
						expect(result).to.equal 'someOutput'

					eval(result)
					expect(invokeCount).to.equal 2
			


		test "Duplicate imports references will be used even for duplicates across multiple files", ()->
			Promise.all([
				fs.outputFileAsync(tempFile('variable.js'), "output = 'someOutput'")
				fs.outputFileAsync(tempFile('importingA.js'), "import variable.js")
				fs.outputFileAsync(tempFile('importingB.js'), "import variable.js")
			]).then ()->				
				SimplyImport("import 'test/temp/importingA.js'\nimport 'test/temp/importingB.js'\nimport 'test/temp/variable.js'", null, {isStream:true}).then (result)->
					result = result
						.split '\n'
						.map (line, index)-> if [3,4,5].includes(index) then "invokeFn(#{line});" else line
						.join '\n'

					invokeCount = 0
					invokeFn = (result)->
						invokeCount++
						expect(result).to.equal 'someOutput'
					
					eval(result)
					expect(invokeCount).to.equal 3





		suite "Commented imports won't be imported", ()->
			test "JS Syntax", ()->
				importDec = "// import 'test/desc/withquotes.js'"
				SimplyImport(importDec, {silent:true}, {isStream:true}).then (result)->
					expect(result).to.equal importDec
			
			test "CoffeeScript Syntax", ()->
				importDec = "# import 'test/desc/withquotes.js'"
				SimplyImport(importDec, {silent:true}, {isStream:true, isCoffee:true}).then (result)->
					expect(result).to.equal importDec
			
			test "DocBlock Syntax", ()->
				importDec = "* import 'test/desc/withquotes.js'"
				SimplyImport(importDec, {silent:true}, {isStream:true}).then (result)->
					expect(result).to.equal importDec





	suite "Browserify", ()->
		test "If the compiled result contains require statements it will be wrapped by Browserify", ()->
			Promise.all([
				fs.outputFileAsync tempFile('commonJS.js'), 		"var units = require('timeunits');\n import commonJS-invoke"
				fs.outputFileAsync tempFile('commonJS-invoke.js'), 	"invokeFn(units); invokeFn(units);"
			]).then ()->
				SimplyImport("import 'test/temp/commonJS.js'", null, {isStream:true}).then (result)->
					# console.log result
					invokeCount = 0
					invokeFn = (units)->
						invokeCount++
						expect(typeof units).to.be.an.object
						expect(units.hour).to.equal 3600000
					
					eval(result)
					expect(invokeCount).to.equal 2
		

		test "If the compiled result is a coffee file and contains require statements it will be first compiled to JS and then wrapped by Browserify and then wrapped in backticks", ()->
			Promise.all([
				fs.outputFileAsync tempFile('commonJS.coffee'), 		"units = require 'timeunits'\nimport commonJS-invoke.coffee"
				fs.outputFileAsync tempFile('commonJS-invoke.coffee'), 	"invokeFn(units); invokeFn(units);"
			]).then ()->
				SimplyImport("import 'test/temp/commonJS.coffee'", null, {isStream:true, isCoffee:true}).then (result)->
					# console.log result
					expect(result[0]).to.equal '`'
					expect(result.slice(-1)[0]).to.equal '`'
					result = result.slice(1,-1)
					invokeCount = 0
					invokeFn = (units)->
						invokeCount++
						expect(typeof units).to.be.an.object
						expect(units.hour).to.equal 3600000
					
					eval(result)
					expect(invokeCount).to.equal 2







	suite "CoffeeScript", ()->
		test "Imported files will be detected as Coffeescript-type if their extension is '.coffee'", ()->
			fs.outputFileAsync(tempFile('a.coffee'), "import someFile.js").then ()->
				SimplyImport(tempFile('a.coffee')).then (result)->
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
				SimplyImport("import 'test/temp/js-with-backticks.js'", {silent:true}, {isCoffee:true, isStream:true}).then (result)->
					expect(result).to.equal "`var abc = '\\`123\\`\\`';\n// abc \\`123\\` \\``"



		test "Backtick escaping algorithm doesn't escape pre-escaped backticks", ()->
			fs.outputFileAsync(tempFile('js-with-escaped-backticks.js'), "
				var abc = '`123\\``';\n// abc `123\\` `
			").then ()->
				SimplyImport("import 'test/temp/js-with-escaped-backticks.js'", {silent:true}, {isCoffee:true, isStream:true}).then (result)->
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
				SimplyImport("import 'test/temp/docblock.js'", {silent:true}, {isCoffee:true, isStream:true}).then (result)->
					expect(result).to.equal "`AAA;\n \n BBB;\n \n CCC;`"



		test "When a Coffee file imports a JS file, escaped newlines should be removed", ()->
			fs.outputFileAsync(tempFile('newline-escaped.js'), "
				multiLineTrick = 'start \\\n
				middle \\\n
				end \\\n
				'
			").then ()->
				SimplyImport("import 'test/temp/newline-escaped.js'", {silent:true}, {isCoffee:true, isStream:true}).then (result)->
					expect(result).to.equal "`multiLineTrick = 'start  middle  end  '`"



		test "If spacing exists before the import statement, that whitespace will be appended to each line of the imported file", ()->
			fs.outputFileAsync(tempFile('tabbed.coffee'), "
				if true\n\ta = 1\n\tb = 2
			").then ()->
				SimplyImport("\t\timport 'test/temp/tabbed.coffee'", {silent:true}, {isCoffee:true, isStream:true}).then (result)->
					resultLines = result.split '\n'
					expect(resultLines[0]).to.equal '\t\tif true'
					expect(resultLines[1]).to.equal '\t\t\ta = 1'
					expect(resultLines[2]).to.equal '\t\t\tb = 2'



		test "When a JS file attempts to import a Coffee file while options.compileCoffeeChildren is off will cause an error to be thrown", ()->
			fs.outputFileAsync(tempFile('variable.coffee'), "'Imported variable';").then ()->
				SimplyImport("import 'test/temp/variable.coffee'", {silent:true}, {isStream:true})
					.then ()-> expect(true).to.be.false # Shouldn't execute
					.catch (err)-> expect(err).to.be.an.error






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
				expect(imports[0].childPath).to.equal 'withquotes.js'
				expect(imports[1].childPath).to.equal 'noquotes.js'
				expect(imports[2].childPath).to.equal 'withext.js'
				expect(imports[3].childPath).to.equal 'noext.js'
				expect(imports[4].childPath).to.equal 'realNoExt'
				expect(imports[5].childPath).to.equal 'nested/nested1.js'
				expect(imports[6].childPath).to.equal 'dir/index.js'
				expect(imports[7].childPath).to.equal 'variable.js'
				expect(imports).eql importsFromStream



		test "Specifying an options object of {pathOnly:true} will retrieve the file paths of all discovered imports in a file", ()->
			SimplyImport.scanImports('test/temp/importer.js', pathOnly:true).then (imports)->
				expect(imports.length).to.equal 8
				expect(imports[0]).to.equal 'withquotes.js'
				expect(imports[1]).to.equal 'noquotes.js'
				expect(imports[2]).to.equal 'withext.js'
				expect(imports[3]).to.equal 'noext.js'
				expect(imports[4]).to.equal 'realNoExt'
				expect(imports[5]).to.equal 'nested/nested1.js'
				expect(imports[6]).to.equal 'dir/index.js'
				expect(imports[7]).to.equal 'variable.js'



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






	suite.skip "Batch tests", ()->
		test "Standard Import", (done)->
			importedAsModule = SimplyImport('test/samples/standard/_importer.js', {silent:true, preserve:true})
			exec "#{bin} -i test/samples/standard/_importer.js -s -p", (err, stdout, stderr)->
				throw err if err
				imported = stdout.toString()
				
				imported.should.include  "Imported file with quotes"
				imported.should.include  "Imported file without quotes"
				imported.should.include  "Imported file with extension"
				imported.should.include  "Imported file without extension"
				imported.should.include  "Imported file that really doesnt have an extension"
				imported.should.include  "Imported nested level 1"
				imported.should.include  "Imported nested level 2"
				imported.should.include  "Imported index file from dir"
				imported.should.include  "Imported file from dir index file"
				imported.should.include  "import 'dirNoIndex'"
				imported.should.include  "import 'dirNonexistent'"
				imported.should.include  "import 'nonexistent.js'"
				imported.should.include  "Imported variable"
				imported.should.equal importedAsModule
				done()		










		test "Coffeescript Import", (done)->
			importedAsModule = SimplyImport('test/samples/coffeescript/_importer.coffee', {silent:true, preserve:true})
			exec "#{bin} -i test/samples/coffeescript/_importer.coffee -s -p", (err, stdout, stderr)->
				throw err if err
				imported = stdout.toString()
				
				imported.should.include  "Imported file with quotes"
				imported.should.include  "Imported file without quotes"
				imported.should.include  "Imported file with extension"
				imported.should.include  "Imported file without extension"
				imported.should.include  "Imported nested level 1"
				imported.should.include  "Imported nested level 2"
				imported.should.include  "Imported index file from dir"
				imported.should.include  "Imported file from dir index file"
				imported.should.include  "import 'nonexistent.coffee'"		
				imported.should.include  "Imported variable"
				imported.should.equal importedAsModule
				done()
		











		test "Coffeescript (tabbed) Import", (done)->
			importedAsModule = SimplyImport('test/samples/coffeescript-tabbed/_importer.coffee', {silent:true, preserve:true})
			exec "#{bin} -i test/samples/coffeescript-tabbed/_importer.coffee -s -p", (err, stdout, stderr)->
				throw err if err
				imported = stdout.toString()
				
				imported.should.include  "Imported file with quotes"
				imported.should.include  "Imported file without quotes"
				imported.should.include  "\t('Imported file with extension"
				imported.should.match  /\t\(\'Imported file with extension/
				imported.should.include  "\t\t('Imported nested level 1"
				imported.should.include  "Imported nested level 2"
				imported.should.include  "import 'nonexistent.coffee'"
				imported.should.include  "\tvariable = 'Imported variable'"
				imported.should.equal importedAsModule
				done()
		











		test "Mixed (coffee+js) Import", (done)->
			importedAsModule = SimplyImport('test/samples/mixed/_importer.coffee', {silent:true, preserve:true})
			exec "#{bin} -i test/samples/mixed/_importer.coffee -s -p", (err, stdout, stderr)->
				throw err if err
				imported = stdout.toString()
				
				imported.should.include  "Imported file with quotes"
				imported.should.include  "Imported file without quotes"
				imported.should.include  "Imported file with extension"
				imported.should.include  "Imported file without extension"
				imported.should.include  "Imported nested level 1"
				imported.should.include  "Imported nested level 2"
				imported.should.include  "('Imported nested level 1');"
				imported.should.include  "import 'nonexistent.coffee'"		
				imported.should.include  "Imported variable"
				imported.should.equal importedAsModule
				done()














		
		test "Conditions Import", (done)->
			importedAsModule = SimplyImport('test/samples/conditions/_importer.js', {conditions:['yes', 'yes1'], silent:true})
			exec "#{bin} -i test/samples/conditions/_importer.js -c yes yes1 -s", (err, stdout, stderr)->
				throw err if err
				imported = stdout.toString()

				imported.should.include  "Imported file with quotes"
				imported.should.include  "Imported file without quotes"
				imported.should.include  "Imported file with extension"
				imported.should.not.include  "Imported file without extension"
				imported.should.include  "Imported nested level 1"
				imported.should.not.include  "Imported nested level 2"
				imported.should.not.include  "import [no] 'nonexistent.js'"		
				imported.should.include  "Imported variable"
				imported.should.equal importedAsModule
				done()














		
		test "Conditions Import (preserve declarations)", (done)->
			importedAsModule = SimplyImport('test/samples/conditions/_importer.js', {conditions:['yes', 'yes1'], preserve:true, silent:true})
			exec "#{bin} -i test/samples/conditions/_importer.js -c yes yes1 -s -p", (err, stdout, stderr)->
				throw err if err
				imported = stdout.toString()
				
				imported.should.include  "Imported file with quotes"
				imported.should.include  "Imported file without quotes"
				imported.should.include  "Imported file with extension"
				imported.should.include  "// import [yes, yes1, no] 'noext'"
				imported.should.include  "Imported nested level 1"
				imported.should.include  "// import [no,no, no] 'nested/nested2.js'"
				imported.should.include  "// import [no] 'nonexistent.js'"		
				imported.should.include  "Imported variable"
				imported.should.equal importedAsModule
				done()





































