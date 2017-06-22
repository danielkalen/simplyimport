require('coffee-register');

if (process.env.SOURCE_MAPS) // Always set in Cakefile
	require('source-map-support').install({hookRequire:true})
	
module.exports = require('./lib/compat');