chai = require 'chai'
expect = chai.expect
should = chai.should()
exec = require('child_process').exec
SimplyImport = require '../src/simplyimport.coffee'




suite "SimplyImport", ()->
	
	test "Standard Import", (done)->
		importedAsModule = SimplyImport('test/standard/_importer.js')
		exec "src/bin.coffee -i test/standard/_importer.js -s", (err, stdout, stderr)->
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
		importedAsModule = SimplyImport('test/coffeescript/_importer.coffee')
		exec "src/bin.coffee -i test/coffeescript/_importer.coffee -s", (err, stdout, stderr)->
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
		importedAsModule = SimplyImport('test/coffeescript-tabbed/_importer.coffee')
		exec "src/bin.coffee -i test/coffeescript-tabbed/_importer.coffee -s", (err, stdout, stderr)->
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
		importedAsModule = SimplyImport('test/mixed/_importer.coffee')
		exec "src/bin.coffee -i test/mixed/_importer.coffee -s", (err, stdout, stderr)->
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
		importedAsModule = SimplyImport('test/conditions/_importer.js', null, {'conditions':['yes', 'yes1']})
		exec "src/bin.coffee -i test/conditions/_importer.js -c yes yes1 -s", (err, stdout, stderr)->
			throw err if err
			imported = stdout.toString()
			console.log imported
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
		importedAsModule = SimplyImport('test/conditions/_importer.js', null, {'conditions':['yes', 'yes1'], 'preserve':true})
		exec "src/bin.coffee -i test/conditions/_importer.js -c yes yes1 -s -p", (err, stdout, stderr)->
			throw err if err
			imported = stdout.toString()
			
			imported.should.include  "Imported file with quotes"
			imported.should.include  "Imported file without quotes"
			imported.should.include  "Imported file with extension"
			imported.should.include  "import {yes, yes1, no} 'noext'"
			imported.should.include  "Imported nested level 1"
			imported.should.include  "import {no,no, no} 'nested/nested2.js'"
			imported.should.include  "import {no} 'nonexistent.js'"		
			imported.should.include  "Imported variable"
			imported.should.equal importedAsModule
			done()





































