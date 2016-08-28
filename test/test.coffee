fs = require 'fs-extra'
chai = require 'chai'
expect = chai.expect
should = chai.should()
exec = require('child_process').exec
SimplyImport = require '../src/simplyimport.coffee'




suite "SimplyImport", ()->
	suite "Batch tests", ()->
		test "Standard Import", (done)->
			importedAsModule = SimplyImport('test/samples/standard/_importer.js', {silent:true, preserve:true})
			exec "src/cli.coffee -i test/samples/standard/_importer.js -s -p", (err, stdout, stderr)->
				throw err if err
				imported = stdout.toString()
				
				imported.should.include  "Imported file with quotes"
				imported.should.include  "Imported file without quotes"
				imported.should.include  "Imported file with extension"
				imported.should.include  "Imported file without extension"
				imported.should.include  "Imported nested level 1"
				imported.should.include  "Imported nested level 2"
				imported.should.include  "import 'nonexistent.js'"
				imported.should.include  "Imported variable"
				imported.should.equal importedAsModule
				done()		










		test "Coffeescript Import", (done)->
			importedAsModule = SimplyImport('test/samples/coffeescript/_importer.coffee', {silent:true, preserve:true})
			exec "src/cli.coffee -i test/samples/coffeescript/_importer.coffee -s -p", (err, stdout, stderr)->
				throw err if err
				imported = stdout.toString()
				
				imported.should.include  "Imported file with quotes"
				imported.should.include  "Imported file without quotes"
				imported.should.include  "Imported file with extension"
				imported.should.include  "Imported file without extension"
				imported.should.include  "Imported nested level 1"
				imported.should.include  "Imported nested level 2"
				imported.should.include  "import 'nonexistent.coffee'"		
				imported.should.include  "Imported variable"
				imported.should.equal importedAsModule
				done()
		











		test "Coffeescript (tabbed) Import", (done)->
			importedAsModule = SimplyImport('test/samples/coffeescript-tabbed/_importer.coffee', {silent:true, preserve:true})
			exec "src/cli.coffee -i test/samples/coffeescript-tabbed/_importer.coffee -s -p", (err, stdout, stderr)->
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
			exec "src/cli.coffee -i test/samples/mixed/_importer.coffee -s -p", (err, stdout, stderr)->
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
			exec "src/cli.coffee -i test/samples/conditions/_importer.js -c yes yes1 -s", (err, stdout, stderr)->
				throw err if err
				imported = stdout.toString()

				imported.should.include  "Imported file with quotes"
				imported.should.include  "Imported file without quotes"
				imported.should.include  "Imported file with extension"
				imported.should.not.include  "Imported file without extension"
				imported.should.include  "Imported nested level 1"
				imported.should.not.include  "Imported nested level 2"
				imported.should.not.include  "import {.+} 'nonexistent.js'"		
				imported.should.include  "Imported variable"
				imported.should.equal importedAsModule
				done()














		
		test "Conditions Import (preserve declarations)", (done)->
			importedAsModule = SimplyImport('test/samples/conditions/_importer.js', {conditions:['yes', 'yes1'], preserve:true, silent:true})
			exec "src/cli.coffee -i test/samples/conditions/_importer.js -c yes yes1 -s -p", (err, stdout, stderr)->
				throw err if err
				imported = stdout.toString()
				
				imported.should.include  "Imported file with quotes"
				imported.should.include  "Imported file without quotes"
				imported.should.include  "Imported file with extension"
				imported.should.include  "// import {yes, yes1, no} 'noext'"
				imported.should.include  "Imported nested level 1"
				imported.should.include  "// import {no,no, no} 'nested/nested2.js'"
				imported.should.include  "// import {no} 'nonexistent.js'"		
				imported.should.include  "Imported variable"
				imported.should.equal importedAsModule
				done()









	suite "CoffeeScript", ()->
		test "Imported files will be detected as Coffeescript-type if their extension is '.coffee'", ()->


		test "If no extension is provided for an import and the importing parent is a Coffee file then the import will be treated as a Coffee file", ()->
		

		test "If an extension-less import is treated as a Coffee file but doesn't exist, SimplyImport will attempt treat it as a JS file", ()->


		test "If an importer is a JS file attempting to import a Coffee file, the Coffee file will be compiled to JS", ()->







	suite "General", ()->
		test "Commented imports won't be imported", ()->
			importDec = "// import 'test/samples/standard/withquotes.js'"
			result = SimplyImport importDec, {silent:true}, {isStream:true}
			expect(result).to.equal importDec
		


		test "Failed imports will be kept in a commented-out form if options.preserve is set to true", ()->
			importDec = "import 'test/nonexistent.js'"
			result = SimplyImport importDec, {silent:true, preserve:true}, {isStream:true}
			expect(result).to.equal "// #{importDec}"



		test "If output path is a directory, the result will be written to the a file with the same name as the input file appended with .compiled at the end", (done)->
			importDec = "import 'test/nonexistent.js'"
			
			fs.ensureDir 'test/temp/output', ()->
				fs.writeFile 'test/temp/theFile.js', importDec, ()->
					exec "src/cli.coffee -i test/temp/theFile.js -o test/temp/output -s -p", (err, stdout, stderr)->
						throw err if err
						result = null
						expect ()-> result = fs.readFileSync 'test/temp/output/theFile.compiled.js', {encoding:'utf8'}
							.not.to.throw()
						
						expect(result).to.equal "// #{importDec}"

						fs.remove 'test/temp', done



		test "If output path is a directory, an input path must be provided", (done)->
			exec "echo 'whatever' | src/cli.coffee -o test/", (err, stdout, stderr)->
				expect(err).to.be.an 'error'
				done()



































