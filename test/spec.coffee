fs = require 'fs-extra'
chai = require 'chai'
chaiSpies = require 'chai-spies'
chai.use chaiSpies
expect = chai.expect
should = chai.should()
regEx = require '../lib/regex'
exec = require('child_process').exec

if process.env.forCoverage
	SimplyImport = require '../forCoverage/simplyimport.js'
else
	SimplyImport = require '../index.js'




suite "SimplyImport", ()->
	suite "General", ()->
		test "Failed imports will be kept in a commented-out form if options.preserve is set to true", ()->
			importDec = "import 'test/nonexistent'"
			result = SimplyImport importDec, {silent:true, preserve:true}, {isStream:true}
			expect(result).to.equal "// #{importDec}"



		test "If output path is a directory, the result will be written to the a file with the same name as the input file appended with .compiled at the end", (done)->
			importDec = "import 'test/nonexistent.js'"
			
			fs.ensureDir 'test/temp/output', ()->
				fs.writeFile 'test/temp/theFile.js', importDec, ()->
					exec "./bin -i test/temp/theFile.js -o test/temp/output -s -p", (err, stdout, stderr)->
						throw err if err
						result = null
						expect ()-> result = fs.readFileSync 'test/temp/output/theFile.compiled.js', {encoding:'utf8'}
							.not.to.throw()
						
						expect(result).to.equal "// #{importDec}"

						fs.remove 'test/temp', done



		test "If output path is a directory, an input path must be provided", (done)->
			exec "echo 'whatever' | ./bin -o test/", (err, stdout, stderr)->
				expect(err).to.be.an 'error'
				done()



		test "Imports will be minified if options.uglify is set", ()->
			result = SimplyImport "import 'test/samples/standard/uglify-subject.js'", {uglify:true}, {isStream:true}
			expect(result).to.equal "if(a)var abc=!0;else var abc=!1;"



		test "Imports within imports should not be resolved if options.recursive is set to false", ()->
			result = SimplyImport "import 'test/samples/standard/nested/nested1.js'", {recursive:false}, {isStream:true}
			expect(result).to.equal "('Imported nested level 1');\nimport 'nested/nested2.js'"



		test "Unquoted imports that have whitespace after them should not make any difference", ()->
			result = SimplyImport "import test/samples/standard/nested/nested1.js\t", {recursive:false}, {isStream:true}
			expect(result).to.equal "('Imported nested level 1');\nimport 'nested/nested2.js'"



		test "Duplicate imports in the same file will be ignored", ()->
			importDec = "import 'test/samples/standard/variable.js'"
			result = SimplyImport importDec+'\n'+importDec, {preserve:true, silent:true}, {isStream:true}

			expect(result).to.equal "'Imported variable';\n// #{importDec}"



		test "Duplicate imports in mixed files will be ignored", ()->
			importDec = "import 'test/samples/standard/variable.js'"
			importDec2 = "import 'test/samples/standard/importing_duplicate.js'"
			result = SimplyImport importDec+'\n'+importDec2, {preserve:true, silent:true}, {isStream:true}

			expect(result).to.equal "'Imported variable';\n// import 'variable.js'"



		test "Import history can be tracked across multiiple imports by prepending the import history of an import process to the beginning of the output file", ()->
			importOpts = {track:true, silent:true, preserve:true}
			imports = [
				"import 'test/samples/standard/withquotes.js'"
				"import 'test/samples/standard/noext'"
				"import 'test/samples/standard/nested/nested1.js'"
			]
			extraImport = "import test/samples/standard/noquotes.js"
			trackedHashes = []

			result1 = SimplyImport imports.join('\n'), importOpts, {isStream:true}
			result1.replace regEx.trackedImport, (entire, hash)-> trackedHashes.push hash

			expect(trackedHashes.length).to.equal 4


			trackedHashes.length = 0
			result2 = SimplyImport result1+'\n'+imports.join('\n')+'\n'+extraImport, importOpts, {isStream:true}
			result2.replace regEx.trackedImport, (entire, hash)-> trackedHashes.push hash

			expect(trackedHashes.length).to.equal 5
			result2.should.include  "Imported file with quotes"
			result2.should.include  "Imported file without quotes"
			result2.should.include  "Imported file without extension"
			result2.should.include  "Imported nested level 1"
			result2.should.include  "Imported nested level 2"

			for importDec in imports
				result2.should.include "// #{importDec}"




		suite "Commented imports won't be imported", ()->
			test "JS Syntax", ()->
				importDec = "// import 'test/samples/standard/withquotes.js'"
				result = SimplyImport importDec, {silent:true}, {isStream:true}
				expect(result).to.equal importDec
			
			test "CoffeeScript Syntax", ()->
				importDec = "# import 'test/samples/standard/withquotes.js'"
				result = SimplyImport importDec, {silent:true}, {isStream:true, isCoffee:true}
				expect(result).to.equal importDec
			
			test "DocBlock Syntax", ()->
				importDec = "* import 'test/samples/standard/withquotes.js'"
				result = SimplyImport importDec, {silent:true}, {isStream:true}
				expect(result).to.equal importDec


		test.skip "Browserify Packages", ()->
			# importDec = "var times = require('timeunits')"
			importDec = "import 'test/samples/standard/commonjs.js'"
			result = SimplyImport importDec, null, {isStream:true}
			# expect(result).to.equal importDec
			console.log result







	suite "CoffeeScript", ()->
		test "Imported files will be detected as Coffeescript-type if their extension is '.coffee'", ()->
			result = SimplyImport 'test/samples/mixed/coffee-importing-js.coffee', {silent:true}
			expect(result).to.equal "`'Imported variable';`"



		test "If no extension is provided for an import and the importing parent is a Coffee file then the import will be treated as a Coffee file", ()->
			result = SimplyImport "import 'test/samples/coffeescript/varDec'", {silent:true}, {isStream:true, isCoffee:true}
			expect(result).to.equal "abc = 50"
		


		test "If an extension-less import is treated as a Coffee file but doesn't exist, SimplyImport will attempt treat it as a JS file", ()->
			result = SimplyImport "import 'test/samples/mixed/variable'", {silent:true}, {isStream:true, isCoffee:true}
			expect(result).to.equal "`'Imported variable';`"



		test "If an importer is a JS file attempting to import a Coffee file, the Coffee file will be compiled to JS", ()->
			result = SimplyImport "import 'test/samples/coffeescript/varDec.coffee'", {silent:true, compileCoffeeChildren:true}, {isStream:true}
			expect(result).to.equal "var abc;\n\nabc = 50;\n"



		test "When a Coffee file imports a JS file, single-line comments shouldn't be removed", ()->
			result = SimplyImport "import 'test/samples/mixed/js-with-backticks.js'", {silent:true}, {isCoffee:true, isStream:true}
			expect(result).to.contain "// abc"



		test "When a Coffee file imports a JS file, all the backticks in the JS file will be escaped", ()->
			result = SimplyImport "import 'test/samples/mixed/js-with-backticks.js'", {silent:true}, {isCoffee:true, isStream:true}
			expect(result).to.equal "`var abc = '\\`123\\`\\`';\n// abc \\`123\\` \\``"



		test "Backtick escaping algorithm doesn't escape pre-escaped backticks", ()->
			result = SimplyImport "import 'test/samples/mixed/js-with-escaped-backticks.js'", {silent:true}, {isCoffee:true, isStream:true}
			expect(result).to.equal "`var abc = '\\`123\\`\\`';\n// abc \\`123\\` \\``"



		test "When a Coffee file imports a JS file, all DocBlocks' should be removed", ()->
			result = SimplyImport "import 'test/samples/mixed/docblock.js'", {silent:true}, {isCoffee:true, isStream:true}
			expect(result).to.equal "`'start';\n\n'middle';\n\n'end';`"



		test "When a Coffee file imports a JS file, escaped newlines should be removed", ()->
			result = SimplyImport "import 'test/samples/mixed/newline-escaped.js'", {silent:true}, {isCoffee:true, isStream:true}
			expect(result).to.equal "`multiLineTrick = 'start middle end '`"



		test "If spacing exists before the import statement, that whitespace will be appended to each line of the imported file", ()->
			result = SimplyImport "\t\timport 'test/samples/coffeescript/tabbed.coffee'", {silent:true}, {isStream:true, isCoffee:true}
			resultLines = result.split '\n'
			expect(resultLines[0]).to.equal '\t\tif true'
			expect(resultLines[1]).to.equal '\t\t\ta = 1'
			expect(resultLines[2]).to.equal '\t\t\tb = 2'








	suite "API", ()->
		test "Calling SimplyImport.scanImports(path) will retrieve import objects for all discovered imports in a file", ()->
			directFileContent = fs.readFileSync('test/samples/standard/_importer.js', {encoding:'utf8'})
			imports = SimplyImport.scanImports 'test/samples/standard/_importer.js'
			importsFromStream = SimplyImport.scanImports directFileContent, {isStream:true, context:'test/samples/standard'}

			expect(imports.length).to.equal 11
			expect(imports[0].childPath).to.equal 'withquotes.js'
			expect(imports[1].childPath).to.equal 'noquotes.js'
			expect(imports[2].childPath).to.equal 'withext.js'
			expect(imports[3].childPath).to.equal 'noext.js'
			expect(imports[4].childPath).to.equal 'realNoExt'
			expect(imports[5].childPath).to.equal 'nested/nested1.js'
			expect(imports[6].childPath).to.equal 'dir/index.js'
			expect(imports[7].childPath).to.equal 'dirNoIndex/index.js'
			expect(imports[8].childPath).to.equal 'dirNonexistent'
			expect(imports[9].childPath).to.equal 'nonexistent.js'
			expect(imports[10].childPath).to.equal 'variable.js'
			expect(imports).eql importsFromStream



		test "Specifying an options object of {pathOnly:true} will retrieve the file paths of all discovered imports in a file", ()->
			imports = SimplyImport.scanImports 'test/samples/standard/_importer.js', {pathOnly:true}

			expect(imports.length).to.equal 11
			expect(imports[0]).to.equal 'withquotes.js'
			expect(imports[1]).to.equal 'noquotes.js'
			expect(imports[2]).to.equal 'withext.js'
			expect(imports[3]).to.equal 'noext.js'
			expect(imports[4]).to.equal 'realNoExt'
			expect(imports[5]).to.equal 'nested/nested1.js'
			expect(imports[6]).to.equal 'dir/index.js'
			expect(imports[7]).to.equal 'dirNoIndex/index.js'
			expect(imports[8]).to.equal 'dirNonexistent'
			expect(imports[9]).to.equal 'nonexistent.js'
			expect(imports[10]).to.equal 'variable.js'



		test "Specifying an options object of {pathOnly:true, withContext:true} will retrieve absolute file paths of all discovered imports in a file", ()->
			imports = SimplyImport.scanImports 'test/samples/standard/_importer.js', {pathOnly:true, withContext:true}
			context = "#{__dirname}/samples/standard"

			expect(imports.length).to.equal 11
			expect(imports[0]).to.equal "#{context}/withquotes.js"
			expect(imports[1]).to.equal "#{context}/noquotes.js"
			expect(imports[2]).to.equal "#{context}/withext.js"
			expect(imports[3]).to.equal "#{context}/noext.js"
			expect(imports[4]).to.equal "#{context}/realNoExt"
			expect(imports[5]).to.equal "#{context}/nested/nested1.js"
			expect(imports[6]).to.equal "#{context}/dir/index.js"
			expect(imports[7]).to.equal "#{context}/dirNoIndex/index.js"
			expect(imports[8]).to.equal "#{context}/dirNonexistent"
			expect(imports[9]).to.equal "#{context}/nonexistent.js"
			expect(imports[10]).to.equal "#{context}/variable.js"



		test "Specifying an options object of {isStream:true, pathOnly:true} will assume that the first argument is the contents of the file", ()->
			imports = SimplyImport.scanImports 'import testImport.js', {isStream:true, pathOnly:true}

			expect(imports.length).to.equal 1
			expect(imports[0]).to.equal 'testImport.js'









	suite "Errors & Warnings", ()->
		test "Importing a nonexistent file will provide a warning", ()->
			warnOrig = console.warn
			console.warn = chai.spy()
			importDec = "import 'test/nonexistent.js'"

			expect(console.warn).to.have.been.called.exactly(0)
			result = SimplyImport importDec, {preserve:true}, {isStream:true}
			
			expect(result).to.equal "// #{importDec}"
			expect(console.warn).to.have.been.called.exactly(1)
			console.warn = warnOrig



		test "Duplicate imports will cause a warning to be displayed", ()->
			warnOrig = console.warn
			warningMessage = ''
			console.warn = chai.spy((message)-> warningMessage=message)
			importDec = "import 'test/samples/standard/importing_duplicate.js'"
			importDec2 = "import 'test/samples/standard/variable.js'"
			
			expect(console.warn).to.have.been.called.exactly(0)
			result = SimplyImport importDec+'\n'+importDec2, {preserve:true}, {isStream:true}

			expect(result).to.equal "'Imported variable';\n// #{importDec2}"
			expect(warningMessage).to.include 'Duplicate import found'
			expect(warningMessage).to.include 'test/samples/standard/variable.js'
			expect(warningMessage).to.include 'test/samples/standard/importing_duplicate.js'
			
			expect(console.warn).to.have.been.called.exactly(1)
			console.warn = warnOrig



		test "Providing SimplyImport with an invalid input path will cause an error to be thrown", ()->
			expect ()-> SimplyImport 'test/nonexistent.js', {silent:true}
				.to.throw()


		test "When a JS file attempts to import a Coffee file while options.compileCoffeeChildren is off will cause an error to be thrown", ()->
			expect ()-> SimplyImport "import 'test/samples/coffeescript/variable.coffee'", null, {isStream:true}
				.to.throw()
			






	suite "Batch tests", ()->
		test "Standard Import", (done)->
			importedAsModule = SimplyImport('test/samples/standard/_importer.js', {silent:true, preserve:true})
			exec "./bin -i test/samples/standard/_importer.js -s -p", (err, stdout, stderr)->
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
			exec "./bin -i test/samples/coffeescript/_importer.coffee -s -p", (err, stdout, stderr)->
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
			exec "./bin -i test/samples/coffeescript-tabbed/_importer.coffee -s -p", (err, stdout, stderr)->
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
			exec "./bin -i test/samples/mixed/_importer.coffee -s -p", (err, stdout, stderr)->
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
			exec "./bin -i test/samples/conditions/_importer.js -c yes yes1 -s", (err, stdout, stderr)->
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
			exec "./bin -i test/samples/conditions/_importer.js -c yes yes1 -s -p", (err, stdout, stderr)->
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





































