var exec = require('child_process').exec;

exec('node '+__dirname+'/../../bin/simplyimport -i '+__dirname+'/_importer.js -c yes yes1 -s', function(error, stdout, stderror){
	if (error) console.log(error);
	if (stderror) console.log(stderror);
	var stdout = stdout.toString(),
		passedTests = true;
	
	if (!stdout.match(/Imported file with quotes/)) {console.log('\x1b[31mFailed To Import file with quotes\x1b[0m'); passedTests = false;}
	if (!stdout.match(/Imported file without quotes/)) {console.log('\x1b[31mFailed To Import file without quotes\x1b[0m'); passedTests = false;}
	if (!stdout.match(/Imported file with extension/)) {console.log('\x1b[31mFailed To Import file with extension\x1b[0m'); passedTests = false;}
	if (stdout.match(/Imported file without extension/)) {console.log('\x1b[31mImported file without extension when failed to match 1 condition\x1b[0m'); passedTests = false;}
	if (!stdout.match(/Imported nested level 1/)) {console.log('\x1b[31mFailed To Import nested file at level 1\x1b[0m'); passedTests = false;}
	if (stdout.match(/Imported nested level 2/)) {console.log('\x1b[31mImported file nested file when failed to match all condition\x1b[0m'); passedTests = false;}
	if (stdout.match(/\@import \{.+\} 'nonexistent\.js'/)) {console.log('\x1b[31mImported non-existent file or there was an error relating to it.\x1b[0m'); passedTests = false;}

	if (passedTests) {
		console.log('Conditional Import - \x1b[32mPassed All Tests\x1b[0m');
	}
});