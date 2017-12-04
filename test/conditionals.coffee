helpers = require './helpers'
{assert, expect, sample, debug, temp, runCompiled, processAndRun, emptyTemp, badES6Support} = helpers

suite "conditionals", ()->
	test "conditional blocks are marked by start/end comments and are removed if the statement in the start comment is falsey", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					"main.js": """
						abc = 'aaa';

						// simplyimport:if VAR_A
						def = 'bbb';
						abc = def.slice(1)+abc.slice(2).toUpperCase()
						// simplyimport:end

						// simplyimport:if VAR_B
						ghi = 'ccc';
						abc = ghi.slice(1)+abc.slice(2).toUpperCase()
						// simplyimport:end

						result = abc;
					"""

			.then ()->
				processAndRun file:temp('main.js')
			.then ({context, writeToDisc})->
				assert.equal context.abc, 'aaa'
				assert.equal context.def, undefined
				assert.equal context.ghi, undefined
				assert.equal context.result, context.abc
			
			.then ()->
				process.env.VAR_A = 1
				processAndRun file:temp('main.js')
			.then ({context, writeToDisc})->
				assert.equal context.abc, 'bbA'
				assert.equal context.def, 'bbb'
				assert.equal context.ghi, undefined
				assert.equal context.result, context.abc
			
			.then ()->
				process.env.VAR_B = 1
				processAndRun file:temp('main.js')
			.then ({context, compiled})->
				assert.equal context.abc, 'ccA'
				assert.equal context.def, 'bbb'
				assert.equal context.ghi, 'ccc'
				assert.equal context.result, context.abc
				assert.notInclude compiled, 'simplyimport'


	test "names in statements will be treated as env variables", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					"main.js": """
						abc = 'aaa';

						// simplyimport:if somevar = 'abc'
						abc = 'bbb';
						// simplyimport:end
					"""

			.then ()->
				process.env.somevar = '123'
				processAndRun file:temp('main.js')
			.then ({context, writeToDisc})->
				assert.equal context.abc, 'aaa'

			.then ()->
				process.env.somevar = 'abc'
				processAndRun file:temp('main.js')
			.then ({context, writeToDisc})->
				assert.equal context.abc, 'bbb'


	test "BUNDLE_TARGET in statements will be resolved to the task's options.target", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					"main.js": """
						a = 'nothing';
						b = '';
						c = '';
						d = 'nothing';

						// simplyimport:if bundle_target = 'node'
						a = 'node';
						// simplyimport:end

						// simplyimport:if bundle_TARGET = 'browser'
						a = 'browser';
						// simplyimport:end

						// simplyimport:if BUNDLE_TARGET = 'node'
						b = 'node';
						c = 'node';
						// simplyimport:end

						// simplyimport:if BUNDLE_TARGET === 'browser'
						b = 'browser';
						c = 'browser';
						// simplyimport:end

						// simplyimport:if BUNDLE_TARGET = 'something-else'
						d = 'something';
						// simplyimport:end
					"""

			.then ()->
				assert.equal typeof process.env.BUNDLE_TARGET, 'undefined'
				processAndRun file:temp('main.js')
			.then ({context})->
				assert.equal context.a, 'nothing'
				assert.equal context.b, 'browser'
				assert.equal context.c, 'browser'
				assert.equal context.d, 'nothing'

			.then ()->
				assert.equal typeof process.env.BUNDLE_TARGET, 'undefined'
				processAndRun file:temp('main.js'), target:'node'
			.then ({context})->
				assert.equal context.a, 'nothing'
				assert.equal context.b, 'node'
				assert.equal context.c, 'node'
				assert.equal context.d, 'nothing'

			.then ()->
				process.env.BUNDLE_TARGET = 'something-else'
				processAndRun file:temp('main.js')
			.then ({context})->
				assert.equal context.a, 'nothing'
				assert.equal context.b, 'browser'
				assert.equal context.c, 'browser'
				assert.equal context.d, 'nothing'


	test "statements will be parsed as js expressions and can thus can have standard punctuators and invoke standard globals", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					"main.js": """
						abc = 'aaa';

						// simplyimport:if VAR_A == 'abc' && VAR_B == 'def'
						abc = 'bbb';
						// simplyimport:end

						// simplyimport:if /deff/.test(VAR_B) || /ghi/.test(VAR_C)
						def = 'def';
						// simplyimport:end
					"""

			.then ()->
				process.env.VAR_A = 'abc'
				processAndRun file:temp('main.js')
			.then ({context, writeToDisc})->
				assert.equal context.abc, 'aaa'
				assert.equal context.def, undefined

			.then ()->
				process.env.VAR_B = 'def'
				processAndRun file:temp('main.js')
			.then ({context, writeToDisc})->
				assert.equal context.abc, 'bbb'
				assert.equal context.def, undefined

			.then ()->
				process.env.VAR_C = 'ghi'
				processAndRun file:temp('main.js')
			.then ({context, writeToDisc})->
				assert.equal context.abc, 'bbb'
				assert.equal context.def, 'def'


	test "punctuator normalization (=|==|=== -> ==), (!=|!== -> !=), (| -> ||), (& -> &&)", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					"main.js": """
						aaa = 'aaa';

						// simplyimport:if VAR_A = 'abc' | VAR_A === 123
						bbb = 'bbb';
						// simplyimport:end

						// simplyimport:if typeof VAR_B = 'string' & VAR_B === 40 && parseFloat(VAR_C) !== 1.58 & parseFloat(VAR_C) === '12.58'
						ccc = 'ccc';
						// simplyimport:end

						// simplyimport:if typeof VAR_C == 'object' | typeof parseInt(VAR_C) == 'number'
						ddd = 'ddd';
						// simplyimport:end

						// simplyimport:if isNaN(VAR_D) & typeof parseInt(VAR_C) == 'number' && Boolean(12) = true
						eee = 'eee';
						// simplyimport:end

						// simplyimport:if parseInt(VAR_E) == 3 && VAR_E.split('.')[1] === 23
						fff = 'fff';
						// simplyimport:end
					"""

			.then ()->
				process.env.VAR_A = '123'
				process.env.VAR_B = '40'
				process.env.VAR_C = '12.58'
				process.env.VAR_D = 'TEsT'
				process.env.VAR_E = '3.23.10'
				processAndRun file:temp('main.js')
			.then ({context, writeToDisc})->
				assert.equal context.aaa, 'aaa'
				assert.equal context.bbb, 'bbb'
				assert.equal context.ccc, 'ccc'
				assert.equal context.ddd, 'ddd'
				assert.equal context.eee, 'eee'
				assert.equal context.fff, 'fff'


	test "if a 'simplyimport:end' comment is missing then it will be auto inserted at the file's end", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					"main.js": """
						aaa = 'aaa';

						// simplyimport:if var1
						bbb = 'bbb';
						// simplyimport:end

						// simplyimport:if !var2
						ccc = 'ccc';


						var result = aaa
					"""

			.then ()->
				process.env.var1 = true
				processAndRun file:temp('main.js')
			.then ({context, writeToDisc})->
				writeToDisc()
				assert.equal context.aaa, 'aaa'
				assert.equal context.bbb, 'bbb'
				assert.equal context.ccc, 'ccc'
				assert.equal context.result, undefined

			.then ()->
				process.env.var2 = true
				processAndRun file:temp('main.js')
			.then ({context, writeToDisc})->
				assert.equal context.aaa, 'aaa'
				assert.equal context.bbb, 'bbb'
				assert.equal context.ccc, undefined
				assert.equal context.result, undefined


	test "conditional statements will be processed prior to force inline imports", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					"main.js": """
						abc = importInline "./a.js";

						// simplyimport:if var3
						importInline "./b"
						// simplyimport:end

						// simplyimport:if !var4
						importInline "./c"
						// simplyimport:end

						// simplyimport:if !var5
						importInline "./c"
						import "./d"
						// simplyimport:end

						// simplyimport:if var5
						importInline "./e"
						// simplyimport:end
					"""

					"a.js": "aaa = 'aaa'"
					"b.js": "bbb = 'bbb'"
					"c.js": "ccc = 'ccc'"
					"d.js": "ddd = 'ddd'"
					"e.js": "eee = 'eee'"

			.then ()->
				process.env.var5 = 2
				processAndRun file:temp('main.js')
			.then ({context, writeToDisc})->
				assert.equal context.abc, 'aaa'
				assert.equal context.aaa, 'aaa'
				assert.equal context.bbb, undefined
				assert.equal context.ccc, 'ccc'
				assert.equal context.ddd, undefined
				assert.equal context.eee, 'eee'


	test "all conditionals will be included when options.matchAllConditions is set", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					"main.js": """
						abc = 'aaa';

						// simplyimport:if VAR_A == 'abc' && VAR_B == 'def'
						abc = 'bbb';
						// simplyimport:end

						// simplyimport:if /deff/.test(VAR_B) || /ghi/.test(VAR_C)
						def = 'def';
						// simplyimport:end

						// simplyimport:if VAR_C
						ghi = 'ghi';
						// simplyimport:end

						// simplyimport:if VAR_A == 'gibberish'
						jkl = 'jkl';
						// simplyimport:end
					"""

			.then ()->
				process.env.VAR_A = 'abc'
				delete process.env.VAR_B
				delete process.env.VAR_C
				processAndRun file:temp('main.js'), matchAllConditions:true

			.then ({context, writeToDisc})->
				assert.equal context.abc, 'bbb'
				assert.equal context.def, 'def'
				assert.equal context.ghi, 'ghi'
				assert.equal context.jkl, 'jkl'


	suite "with custom options.env", ()->
		suiteSetup ()-> helpers.lib
			'main.js': """
				// simplyimport:if VAR_A = 'AAA'
				exports.a = 'aaa'
				// simplyimport:end

				// simplyimport:if VAR_B = 'bbb'
				exports.b = 'bbb'
				// simplyimport:end

				// simplyimport:if VAR_C = 'CCC'
				exports.c = 'ccc'
				// simplyimport:end

				// simplyimport:if VAR_D = 'DDD'
				exports.d = 'ddd'
				// simplyimport:end
			"""
			'myEnv': """
				VAR_A=AAA
				VAR_C=CCC
				VAR_D=ddd
			"""

		test "options.env = object", ()->
			Promise.resolve()
				.then ()->
					delete process.env.VAR_A
					delete process.env.VAR_B
					process.env.VAR_B = 'bbb'
					process.env.VAR_C = 'ccc'
					process.env.VAR_D = 'CCC'
					processAndRun file:temp('main.js'), env:{VAR_A:'AAA', VAR_C:'CCC', VAR_D:'ddd'}

				.then ({result})->
					assert.equal process.env.VAR_A, undefined
					assert.equal process.env.VAR_B, 'bbb'
					assert.equal process.env.VAR_C, 'ccc'
					assert.equal process.env.VAR_D, 'CCC'
					assert.deepEqual result,
						a: 'aaa'
						b: 'bbb'
						c: 'ccc'

		test "options.env = filepath", ()->
			Promise.resolve()
				.then ()->
					delete process.env.VAR_A
					delete process.env.VAR_B
					process.env.VAR_B = 'bbb'
					process.env.VAR_C = 'ccc'
					process.env.VAR_D = 'CCC'
					processAndRun file:temp('main.js'), env:temp('myEnv')

				.then ({result})->
					assert.equal process.env.VAR_A, undefined
					assert.equal process.env.VAR_B, 'bbb'
					assert.equal process.env.VAR_C, 'ccc'
					assert.equal process.env.VAR_D, 'CCC'
					assert.deepEqual result,
						a: 'aaa'
						b: 'bbb'
						c: 'ccc'

		test "options.env = filepath from package.json", ()->
			Promise.resolve()
				.then ()-> helpers.lib
					'package.json': JSON.stringify(simplyimport:env:'myEnv')
				.then ()->
					delete process.env.VAR_A
					delete process.env.VAR_B
					process.env.VAR_B = 'bbb'
					process.env.VAR_C = 'ccc'
					process.env.VAR_D = 'CCC'
					processAndRun file:temp('main.js')

				.then ({result})->
					assert.equal process.env.VAR_A, undefined
					assert.equal process.env.VAR_B, 'bbb'
					assert.equal process.env.VAR_C, 'ccc'
					assert.equal process.env.VAR_D, 'CCC'
					assert.deepEqual result,
						a: 'aaa'
						b: 'bbb'
						c: 'ccc'









