exports.iife = (args, values, body)-> """
	(function(#{args.join(',')}){
		#{if body then body else ''}
	}).call(#{['this'].concat(values).join(',')})
"""

exports.loader = ()-> """
require = (function(cache,modules){
	return function(r){
		if (!modules[r]) throw new Error(r+' is not a module')
		return cache[r] ? cache[r].exports
						: ( cache[r]={exports:{}}, cache[r].exports=modules[r](require, cache[r], cache[r].exports) );
	};
})({},{});
"""


exports.globalDec = ()-> """
	typeof global !== "undefined" ? global : typeof self !== "undefined" ? self : typeof window !== "undefined" ? window : {}
"""

exports.umdResult = (name, entryID)-> """
	if (typeof define === 'function' && define.umd) {
		define(function(){return require(#{entryID})})
	} else if (typeof module === 'object' && module.exports) {
		module.exports = require(#{entryID})
	} else {
		return this['#{name}'] = require(#{entryID})
	}
"""














