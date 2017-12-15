helpers = require './helpers'
{assert, expect, sample, debug, temp, runCompiled, processAndRun, emptyTemp, SimplyImport} = helpers

suite "inline-imports", ()->
	test "inline imports will be wrapped in paranthesis when the import statement is part of a member expression", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						this.a = require('./a');
						this.a2 = require('./a2').toUpperCase();
						this.a3 = (require('./a3')).toUpperCase();
						this.b = import './b';
						importInline './c';
						this.d = importInline './d'.toLowerCase();
						require('./e');
						this.f = require('./f')();
						this.f2 = import './f2'();
					"""
					'a.js': "abc = 'abc'"
					'a2.js': "abc = 'abc'"
					'a3.js': "abc = 'abc'"
					'b.js': "abc = 'abc'; ABC = 'ABC'"
					'c.js': "var def = 'def'"
					'd.js': "DEF = 'DEF'"
					'e.js': "function eee(){return 'eee'}"
					'f.js': "function fff(){return 'fff'}"
					'f2.js': "function fff(){return 'fff'}"

			.then ()-> processAndRun file:temp('main.js')
			.then ({compiled, result, context})->
				assert.equal context.abc, 'abc'
				assert.equal context.ABC, 'ABC'
				assert.equal context.def, 'def'
				assert.equal context.DEF, 'DEF'
				assert.typeOf context.eee, 'function'
				assert.equal context.eee(), 'eee'
				assert.typeOf context.fff, 'undefined'
				assert.equal context.a, 'abc'
				assert.equal context.a2, 'ABC'
				assert.equal context.a3, 'ABC'
				assert.equal context.b, 'abc'
				assert.equal context.d, 'def'
				assert.equal context.f, 'fff'
				assert.equal context.f2, 'fff'
				assert.equal compiled, """
					this.a = abc = 'abc';
					this.a2 = (abc = 'abc').toUpperCase();
					this.a3 = (abc = 'abc').toUpperCase();
					this.b = abc = 'abc'; ABC = 'ABC';
					var def = 'def';
					this.d = (DEF = 'DEF').toLowerCase();
					function eee(){return 'eee'};
					this.f = (function fff(){return 'fff'})();
					this.f2 = (function fff(){return 'fff'})();
					
				"""


	test "files without exports will be imported inline", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						var abc = require('./fileA').toUpperCase()
						require('./fileB')
						this.ghi = (import './fileC').toLowerCase()
					"""
					'fileA.js': """
						ABC = 'aBc'
					"""
					'fileB.js': """
						var def = 'dEf'
						this.DEF = 'DeF'
					"""
					'fileC.js': """
						'gHI'
					"""

			.then ()-> processAndRun file:temp('main.js')
			.then ({compiled, result, context})->
				assert.notInclude compiled, 'require =', "module-less bundles shouldn't have a module loader"
				assert.equal context.abc, 'ABC'
				assert.equal context.ABC, 'aBc'
				assert.equal context.def, 'dEf'
				assert.equal context.DEF, 'DeF'
				assert.equal context.ghi, 'ghi'


	test "files without exports won't be considered inline if they are imported more than once", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						import 'fileA.js'
						import 'fileB.js'
					"""
					'fileA.js': """
						abcA = (function(){return require('./a')})().toUpperCase()
						defA = (function(){return require('./b')})().toLowerCase()
						ghiA = (function(){return require('./c')})().toUpperCase()
					"""
					'fileB.js': """
						abcB = (function(){return require('./a')})().toUpperCase()
						ghiB = (function(){return require('./c')})().toLowerCase()
					"""
					'a.js': """
						'aBc'
					"""
					'b.js': """
						'dEf'
					"""
					'c.js': """
						ghi = require('./ghi')
						return ghi
					"""
					'ghi.js': """
						module.exports = 'gHi'
					"""

			.then ()-> processAndRun file:temp('main.js'), usePaths:true
			.then ({compiled, result, context})->
				assert.include compiled, 'require =', "should have a module loader"
				assert.equal context.abcA, 'ABC'
				assert.equal context.defA, 'def'
				assert.equal context.ghiA, 'GHI'
				assert.equal context.ghiB, 'ghi'
				assert.equal context.ghi, 'gHi'


	test "inline imports turned into module exports will me modified to export their last expression", ()->
		Promise.resolve()
			.then ()->
				helpers.lib
					'main.js': """
						a = import 'a.js' || import 'a.js'
						b = require('b.js') || require('b.js')
						c = import 'c.js' || import 'c.js'
						d = require('d.js') || require('d.js')
						e = import 'e.js' || import 'e.js'
						f = import 'f.js' || import 'f.js'
						g = import 'g.js' || import 'g.js'
						h = import 'h.js' || import 'h.js'
						i = import 'i.js' || import 'i.js'
						j = import 'j.js' || import 'j.js'
						k = import 'k.js' || import 'k.js'
						lll = 'exporter'
						l = import 'l.js' || import 'l.js'
						m = import 'm.js' || import 'm.js'
					"""
					'a.js': """
						abc = 'aAa'
						abc2 = 'AaA'
					"""
					'b.js': """var def = 'bBb'"""
					'c.js': """'cCc'"""
					'd.js': """function(){return 'dDd'}"""
					'e.js': """[1,5,19]"""
					'f.js': """function fff(){return 'fFf'}"""
					'g.js': """
						var ggg = 'gGg', gGg =12;
						function fff(){return 'fFf'}
						if (0) {throw new Error} else {null}
					"""
					'h.js': """
						function fff(){return 'fFf'}
						var hhh = 'hHh', hHh =13;
						if (0) {throw new Error} else {null}
					"""
					'i.js': """
						function fff(){return 'fFf'}
						var iii = 'iIi', iIi =13;
						iiii = 94
						if (0) {throw new Error} else {null}
					"""
					'j.js': """
						jjj = 95
						if (0) {throw new Error} else {null}
						return jjj
					"""
					'k.js': """
						kkk = 123
						return
					"""
					'l.js': """
						lll.toUpperCase()
					"""
					'm.js': """
						if (0) {throw new Error}
					"""

			.then ()-> processAndRun file:temp('main.js'), ignoreSyntaxErrors:true, usePaths:true, 'script.js', abcA:1
			.then ({compiled, result, context, writeToDisc})->
				assert.equal context.a, 'AaA', 'last assignment should be exported'
				assert.equal context.abc, 'aAa'
				assert.equal context.abc2, 'AaA'
				assert.equal context.b, 'bBb', 'last declaration should be exported'
				assert.equal context.def, undefined
				assert.equal context.c, 'cCc', 'literals should be exported'
				assert.equal typeof context.d, 'function', 'function expressions should be exported'
				assert.equal context.d(), 'dDd', 'function expressions should be exported'
				assert.equal typeof context.e, 'object', 'object literals should be exported'
				assert.deepEqual context.e, [1,5,19], 'object literals should be exported'
				assert.equal typeof context.f, 'function', 'function declarations should be exported'
				assert.equal context.f(), 'fFf', 'function declarations should be exported'
				assert.equal typeof context.g, 'function', 'last declaration/assignment should be exported'
				assert.equal context.g(), 'fFf'
				assert.equal context.h, 13, 'last declaration/assignment should be exported'
				assert.equal context.i, 94, 'last declaration/assignment should be exported'
				assert.equal context.j, 95, 'if last is return it should be modified to export the return argument'
				assert.equal context.k, undefined, 'if last is empty return then nothing will be exported'
				assert.equal context.l, 'EXPORTER', 'last expression should be exported'
				assert.equal context.lll, 'exporter'
				assert.deepEqual context.m, {}, 'nothing should be exported when nothing is available to be exported'






