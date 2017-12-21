helpers = require './helpers'
{assert, expect, sample, debug, temp, runCompiled, processAndRun, emptyTemp, badES6Support} = helpers

suite "common modules", ()->
	test "axios", ()->
		Promise.resolve()
			.then ()-> helpers.lib "main.js": "module.exports = require('axios')"
			.then ()-> processAndRun file:temp('main.js'), null, {XMLHttpRequest:require('xmlhttprequest').XMLHttpRequest, location:require('location')}
			.then ({result, writeToDisc})->
				assert.typeOf result, 'function'
				req = null; token = result.CancelToken.source();
				assert.doesNotThrow ()-> req = result.get('https://google.com', cancelToken:token.token)
				token.cancel('cancelled')
				
				Promise.resolve(req)
					.catch message:'cancelled', (err)->


	test "yo-yo", ()->
		Promise.resolve()
			.then ()-> helpers.lib "main.js": "module.exports = require('yo-yo')"
			.then ()-> processAndRun file:temp('main.js')
			.then ({result})->
				assert.typeOf result, 'function'


	test "smart-extend", ()->
		Promise.resolve()
			.then ()-> helpers.lib "main.js": "module.exports = require('smart-extend')"
			.then ()-> processAndRun file:temp('main.js')
			.then ({result})->
				assert.typeOf result, 'function'
				obj = {a:1, b:2, c:[3,4,5]}
				clone = result.clone.deep.concat obj
				clone2 = result.clone.deep.concat obj, c:[1,2,2]
				assert.notEqual obj, clone
				assert.deepEqual obj, clone
				assert.deepEqual clone2.c, [3,4,5,1,2,2]


	test "formatio", ()->
		Promise.resolve()
			.then ()-> helpers.lib "main.js": "module.exports = require('formatio')"
			.then ()-> processAndRun file:temp('main.js')
			.then ({result})->
				assert.typeOf result, 'object'
				assert.typeOf result.ascii, 'function'


	test "timeunits", ()->
		Promise.resolve()
			.then ()-> helpers.lib "main.js": "module.exports = require('timeunits')"
			.then ()-> processAndRun file:temp('main.js')
			.then ({result})->
				assert.typeOf result, 'object'
				assert Object.keys(result).length > 1


	test "redux", ()->
		Promise.resolve()
			.then ()-> helpers.lib "redux.js": "module.exports = require('redux')"
			.then ()-> processAndRun file:temp('redux.js'), usePaths:true
			.then ({result})->
				assert.typeOf result, 'object'
				assert.typeOf result.createStore, 'function'
				store = result.createStore(->)
				assert.typeOf store.dispatch, 'function'
				assert Object.keys(result).length > 1


	test "lodash", ()->
		Promise.resolve()
			.then ()-> helpers.lib "main.js": "module.exports = require('lodash')"
			.then ()-> processAndRun file:temp('main.js'), usePaths:true
			.then ({result,writeToDisc})->
				assert.typeOf result, 'function'
				assert.typeOf result.last, 'function'
				assert.equal result.last([1,2,3]), 3
				assert Object.keys(result).length > 1


	test "moment", ()->
		Promise.resolve()
			.then ()-> helpers.lib "main.js": "module.exports = require('moment/src/moment.js')"
			.then ()-> processAndRun file:temp('main.js'), usePaths:true, indent:true, 'moment.js'
			.then ({result, writeToDisc})->
				now = Date.now()
				assert.typeOf result, 'function'
				assert.equal (now - 3600000), result(now).subtract(1, 'hour').valueOf()
				assert Object.keys(result).length > 1









