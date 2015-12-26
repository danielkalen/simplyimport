var exec = require('child_process').exec;

exec('node '+__dirname+'/../../simplyimport.js -i '+__dirname+'/_importer.js -s', function(error, stdout, stderror){
	var stdout = stdout.toString(),
		passedTests = true;
	
	if (!stdout.match(/Imported file with quotes/)) {console.log('Failed to import file with quotes'); passedTests = false;}
	if (!stdout.match(/Imported file without quotes/)) {console.log('Failed to import file without quotes'); passedTests = false;}
	if (!stdout.match(/Imported file with extension/)) {console.log('Failed to import file with extension'); passedTests = false;}
	if (!stdout.match(/Imported file without extension/)) {console.log('Failed to import file without extension'); passedTests = false;}
	if (!stdout.match(/Imported nested level 1/)) {console.log('Failed to import nested file at level 1'); passedTests = false;}
	if (!stdout.match(/Imported nested level 2/)) {console.log('Failed to import nested file at level 2'); passedTests = false;}
	if (!stdout.match(/\@import 'nonexistent\.js'/)) {console.log('Imported non-existent file or there was an error relating to it.'); passedTests = false;}

	if (passedTests) {
		console.log('Standard Import - Passed All Tests');
	}
});