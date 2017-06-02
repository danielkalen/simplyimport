require('coffee-register');

if (process.env.SOURCE_MAPS)
	require('source-map-support').install({hookRequire:true})

module.exports = require('./lib');