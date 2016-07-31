chai = require 'chai'
expect = chai.expect
should = chai.should()
exec = require('child_process').exec
SimplyImport = require '../src/simplyimport.coffee'




suite "SimplyImport", ()->
	
	suite "Standard Import", ()->
		
		test "Module method", ()->
			imported = SimplyImport('standard/_importer.js')
			
			imported.should.include  "Imported file with quotes"
			imported.should.include  "Imported file without quotes"
			imported.should.include  "Imported file with extension"
			imported.should.include  "Imported file without extension"
			imported.should.include  "Imported nested level 1"
			imported.should.include  "Imported nested level 2"
			imported.should.include  "\@import 'nonexistent\.js'"

		
		test "CLI method", (done)->
			exec("#{__dirname}/../../bin/simplyimport -i #{__dirname}/_importer.js -s", (error, stdout, stderror)->














