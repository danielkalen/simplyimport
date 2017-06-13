Promise = require 'bluebird'
path = require 'path'
resolveModule = Promise.promisify require('browser-resolve')
basedir = 'basedir':path.resolve(__dirname,'..')

module.exports = (EMPTY_FILE)->
	'': path.resolve(__dirname,'..','node_modules','')
	'assert':					resolveModule.sync 'assert/', basedir
	'zlib':						resolveModule.sync '@danielkalen/browserify-zlib', basedir
	'buffer':					resolveModule.sync 'buffer/', basedir
	'console':					resolveModule.sync 'console-browserify', basedir
	'constants':				resolveModule.sync 'constants-browserify', basedir
	'crypto':					resolveModule.sync 'crypto-browserify', basedir
	'domain':					resolveModule.sync 'domain-browser', basedir
	'events':					resolveModule.sync 'events/', basedir
	'http':						resolveModule.sync 'stream-http', basedir
	'https':					resolveModule.sync 'https-browserify', basedir
	'os':						resolveModule.sync 'os-browserify', basedir
	'path':						resolveModule.sync 'path-browserify', basedir
	'process':					resolveModule.sync 'process/', basedir
	'punycode':					resolveModule.sync 'punycode/', basedir
	'querystring':				resolveModule.sync 'querystring-es3', basedir
	'string_decoder':			resolveModule.sync 'string_decoder', basedir
	'stream':					resolveModule.sync 'stream-browserify', basedir
	'timers':					resolveModule.sync 'timers-browserify', basedir
	'tty':						resolveModule.sync 'tty-browserify', basedir
	'url':						resolveModule.sync 'url/', basedir
	'util':						resolveModule.sync 'util/', basedir
	'vm':						resolveModule.sync 'vm-browserify', basedir

	# none-replaceable modules
	'cluster': EMPTY_FILE
	'dgram': EMPTY_FILE
	'dns': EMPTY_FILE
	'fs': EMPTY_FILE
	'module': EMPTY_FILE
	'net': EMPTY_FILE
	'readline': EMPTY_FILE
	'repl': EMPTY_FILE