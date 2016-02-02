var exec = require('child_process').exec;

exec('node '+__dirname+'/../../simplyimport.js -i '+__dirname+'/_importer.js -c yes yes1 -s -p', function(error, stdout, stderror){
	if (error) console.log(error);
	if (stderror) console.log(stderror);
	var stdout = stdout.toString(),
		passedTests = true;
	
	if (!stdout.match(/Imported file with quotes/)) {console.log('Failed to import file with quotes'); passedTests = false;}
	if (!stdout.match(/Imported file without quotes/)) {console.log('Failed to import file without quotes'); passedTests = false;}
	if (!stdout.match(/Imported file with extension/)) {console.log('Failed to import file with extension'); passedTests = false;}
	if (!stdout.match(/\@import \{.+\} 'noext'/)) {console.log('Imported file without extension when failed to match 1 condition'); passedTests = false;}
	if (!stdout.match(/Imported nested level 1/)) {console.log('Failed to import nested file at level 1'); passedTests = false;}
	if (!stdout.match(/\@import \{.+\} 'nested\/nested2\.js'/)) {console.log('Imported file nested file when failed to match all condition'); passedTests = false;}
	if (!stdout.match(/\@import \{.+\} 'nonexistent\.js'/)) {console.log('Imported non-existent file or there was an error relating to it.'); passedTests = false;}

	if (passedTests) {
		console.log('Conditional Import - Passed All Tests');
	}
});