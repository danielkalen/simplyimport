Path = require 'path'
helpers = require './helpers'
{assert, expect, temp, processAndRun} = helpers

suite "package", ()->
	test "external modules will have their package.json analyzed", ()->
		Promise.resolve()
			.then ()-> helpers.lib
				'main.js': """
					module.exports = require('./internal') + require('external');
				"""
				'internal.js': """
					'abc'
				"""
				'package.json': JSON.stringify
					simplyimport: specific:
						'internal': transform: ['test/helpers/uppercaseTransform']
				'node_modules/external/index.js': """
					module.exports = require('./inner-external')
				"""
				'node_modules/external/inner-external.js': """
					'def'
				"""
				'node_modules/external/package.json': JSON.stringify
					simplyimport: specific:
						'./inner-external': transform: ['test/helpers/uppercaseTransform']
			
			.then ()-> processAndRun file:temp('main.js')
			.then ({result})=> expect(result).to.equal 'ABCDEF'













