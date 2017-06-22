exports.iife = (args, values, body)-> """
	(function(#{args.join(',')}){
		#{if body then body else ''}
	}).call(#{['this'].concat(values).join(',')})
"""

exports.loaderBrowser = (loader)-> """
	#{loader} = (function(cache,modules){
		return function(r){
			if (!modules[r]) throw new Error(r+' is not a module')
			return cache[r] ? cache[r].exports
							: ( cache[r]={exports:{}}, cache[r].exports=modules[r](#{loader}, cache[r], cache[r].exports) );
		};
	})({},{});
"""

exports.loaderNode = (loader)-> """
	#{loader} = (function(cache,modules,nativeRequire){
		return function(r){
			if (!modules[r]) return nativeRequire(r)
			return cache[r] ? cache[r].exports
							: ( cache[r]={exports:{}}, cache[r].exports=modules[r](#{loader}, cache[r], cache[r].exports) );
		};
	})({},{},#{loader});
"""


exports.globalDec = ()-> """
	typeof global !== "undefined" ? global : typeof self !== "undefined" ? self : typeof window !== "undefined" ? window : this
"""

exports.umd = (loader, name, entryID)-> """
	if (typeof define === 'function' && define.umd) {
		define(function(){return #{loader}(#{entryID})})
	} else if (typeof module === 'object' && module.exports) {
		module.exports = #{loader}(#{entryID})
	} else {
		return this['#{name}'] = #{loader}(#{entryID})
	}
"""














