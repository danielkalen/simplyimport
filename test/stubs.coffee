Path = require 'path'
helpers = require './helpers'
{assert, expect, temp, processAndRun} = helpers

suite "stubs", ()->
	suiteSetup ()->
		@defaultExpected =  {a1:'a1', a2:'a2', a3:'a3', b1:'b1', b2:'b2', b3:'b3'}
		helpers.lib
			'main.js': """
				export var a1 = require('./a1')
				export var a2 = require('./a2')
				export var a3 = require('./a3')
				export var b1 = require('./b1')
				export var b2 = require('./b2')
				export var b3 = require('./b3')
			"""
			'stubber.js': """
				export var a1 = require('./a1')
				export var b1 = require('./b1')
				export var c1 = require('./c1')
			"""
			'a1.js': "module.exports = 'a1'"
			'a2/index.coffee': "module.exports = 'a2'"
			'a3/index.js': "module.exports = 'a3'"
			'b1.js': "module.exports = 'b1'"
			'b2/index.coffee': "module.exports = 'b2'"
			'b3/index.js': "module.exports = 'b3'"


	test "file contents can be stubbed via options.stub {<path>:<content>}", ()->
		Promise.resolve()
			.then ()-> processAndRun file:temp('main.js')
			.then ({result})=> expect(result).to.eql @defaultExpected
			.then ()-> processAndRun file:temp('main.js'), stub:
				"#{temp 'a1.js'}": "export default 'A1'"
				"#{temp 'b1.js'}": "export default 'B1'"
				"#{temp 'b3/index.js'}": "export default 'B3'"

			.then ({result})-> expect(result).to.eql
				a1: 'A1'
				a2: 'a2'
				a3: 'a3'
				b1: 'B1'
				b2: 'b2'
				b3: 'B3'


	test "stub keys can be globs", ()->
		Promise.resolve()
			.then ()-> processAndRun file:temp('main.js'), stub:
				"a1": "export default 'A1'"
				"a2": "export default do ()-> 'A2'"
				"b*": "export default 'B*'"

			.then ({result})-> expect(result).to.eql
				a1: 'A1'
				a2: 'A2'
				a3: 'a3'
				b1: 'B*'
				b2: 'B*'
				b3: 'B*'


	test "stubs can be used on non existent files", ()->
		Promise.resolve()
			.then ()-> expect(processAndRun file:temp('stubber.js')).to.be.rejected
			.then ()-> processAndRun file:temp('stubber.js'), stub:
				"a1": "export default 'A1'"
				"c1": "export default 'C1'"

			.then ({result})-> expect(result).to.eql
				a1: 'A1'
				b1: 'b1'
				c1: 'C1'












