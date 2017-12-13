{iterate} = require 'leakage'
global.Promise = require('bluebird').config warnings:false, longStackTraces:false
SimplyImport = require '../'

# test "memory leaks", ()->
Promise.resolve()
	.then ()->
		iterate.async ()->
			SimplyImport(src:"module.exports = require('assert')")
		, iterations: 3
	
	.catch (err)-> console.error(err)