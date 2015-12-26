var exec = require('child_process').exec;

exec('node '+__dirname+'/../../simplyimport.js -i '+__dirname+'/_importer.js -s -u', function(error, stdout, stderror){
	var stdout = stdout.toString(),
		passedTests = true;

	if (!stdout.match(/a="Imported file with quotes\.",b="Imported file without quotes\.",c="Imported file with extension\.",d="Imported file without extension\.",e="Imported nested level 1",f="Imported nested level 2";/)) {
		console.log('Failed to import and uglify properly.'); passedTests = false;
	}

	if (passedTests) {
		console.log('Uglified Import - Passed All Tests');
	}
});