var exec = require('child_process').exec;

exec('node '+__dirname+'/../../bin/simplyimport -i '+__dirname+'/_importer.js -s -u', function(error, stdout, stderror){
	var stdout = stdout.toString(),
		passedTests = true;

	if (!stdout.match(/a="Imported file with quotes\.",b="Imported file without quotes\.",c="Imported file with extension\.",d="Imported file without extension\.",e="Imported nested level 1",f="Imported nested level 2";/)) {
		console.log('\x1b[31mFailed To Import and uglify properly.\x1b[0m'); passedTests = false;
	}

	if (passedTests) {
		console.log('Uglified Import - \x1b[32mPassed All Tests\x1b[0m');
	}
});