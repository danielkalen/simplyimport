helpers = require './helpers'
{assert, expect, sample, debug, temp, runCompiled, processAndRun, emptyTemp, badES6Support} = helpers

suite "path placeholders", ()->
	test "%CWD will resolve to the current working directory of the runner", ()->
		Promise.resolve()
			.then ()-> helpers.lib
				"main.js": """
					aaa = import './a';
					bbb = import '%CWD/test/temp/b';
					ccc = import 'module-c';
				"""
				"a/index.js": """
					module.exports = require('%CWD/test/temp/a/nested/file');
				"""
				"a/nested/file.js": """
					module.exports = 'aaa';
				"""
				"b.js": """
					module.exports = 'bbb';
				"""
				"c.js": """
					module.exports = 'ccc';
				"""
				"node_modules/module-c/package.json": JSON.stringify main:'index.js'
				"node_modules/module-c/index.js": """
					module.exports = import './nested';
				"""
				"node_modules/module-c/nested/index.js": """
					module.exports = import '%CWD/test/temp/c';
				"""
				"node_modules/module-c/c.js": """
					module.exports = 'module-ccc';
				"""

			.then ()-> processAndRun file:temp('main.js')
			.then ({context})->
				assert.equal context.aaa, 'aaa'
				assert.equal context.bbb, 'bbb'
				assert.equal context.ccc, 'ccc'


	test "%BASE will resolve to the dir of the entry file", ()->
		Promise.resolve()
			.then ()-> helpers.lib
				"main.js": """
					aaa = import './a';
					bbb = import '%BASE/b';
					ccc = import 'module-c';
				"""
				"a/index.js": """
					module.exports = require('%BASE/a/nested/file');
				"""
				"a/nested/file.js": """
					module.exports = 'aaa';
				"""
				"b.js": """
					module.exports = 'bbb';
				"""
				"c.js": """
					module.exports = 'ccc';
				"""
				"node_modules/module-c/package.json": JSON.stringify main:'index.js'
				"node_modules/module-c/index.js": """
					module.exports = import './nested';
				"""
				"node_modules/module-c/nested/index.js": """
					module.exports = import '%BASE/c';
				"""
				"node_modules/module-c/c.js": """
					module.exports = 'module-ccc';
				"""

			.then ()-> processAndRun file:temp('main.js')
			.then ({context})->
				assert.equal context.aaa, 'aaa'
				assert.equal context.bbb, 'bbb'
				assert.equal context.ccc, 'module-ccc'


	test "%ROOT will resolve to the dir of the package file", ()->
		Promise.resolve()
			.then ()-> helpers.lib
				"package.json": JSON.stringify main:'main.js'
				"main.js": """
					aaa = import './a';
					bbb = import '%ROOT/b';
					ccc = import 'module-c';
				"""
				"a/index.js": """
					module.exports = require('%ROOT/a/nested/file');
				"""
				"a/nested/file.js": """
					module.exports = 'aaa';
				"""
				"b.js": """
					module.exports = 'bbb';
				"""
				"c.js": """
					module.exports = 'ccc';
				"""
				"node_modules/module-c/package.json": JSON.stringify main:'index.js'
				"node_modules/module-c/index.js": """
					module.exports = import './nested';
				"""
				"node_modules/module-c/nested/index.js": """
					module.exports = import '%ROOT/c';
				"""
				"node_modules/module-c/c.js": """
					module.exports = 'module-ccc';
				"""

			.then ()-> processAndRun file:temp('main.js')
			.then ({context})->
				assert.equal context.aaa, 'aaa'
				assert.equal context.bbb, 'bbb'
				assert.equal context.ccc, 'module-ccc'


	test "custom placeholder can be defined in settings.placeholder and will be resolved relative to the package file", ()->
		Promise.resolve()
			.then ()-> helpers.lib
				"package.json": JSON.stringify main:'main.js', simplyimport:placeholder:{'ABC':'../temp/', 'DEF':'secret'}
				"main.js": """
					aaa = import '%ABC/a';
					bbb = import '%DEF/b';
					ccc = import 'module-c';
				"""
				"a/index.js": """
					module.exports = require('%DEF/a/nested/file');
				"""
				"secret/a/nested/file.js": """
					module.exports = 'aaa';
				"""
				"secret/b.js": """
					module.exports = 'bbb';
				"""
				"secret/c.js": """
					module.exports = 'ccc';
				"""
				"node_modules/module-c/package.json": JSON.stringify main:'index.js', simplyimport:placeholder:{'GHI':'./supersecret'}
				"node_modules/module-c/index.js": """
					module.exports = import './nested';
				"""
				"node_modules/module-c/nested/index.js": """
					module.exports = import '%GHI/c';
				"""
				"node_modules/module-c/supersecret/c.js": """
					module.exports = import '%DEF/c';
				"""

			.then ()-> processAndRun file:temp('main.js')
			.then ({context})->
				assert.equal context.aaa, 'aaa'
				assert.equal context.bbb, 'bbb'
				assert.equal context.ccc, 'ccc'









