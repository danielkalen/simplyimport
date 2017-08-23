exports.iife = (args, values, body)-> """
	(function(#{args.join(',')}){
		#{if body then body else ''}
	}).call(#{['this'].concat(values).join(',')})
"""

exports.loaderBrowser = (loader)-> """
	#{loader} = (function(cache,modules,cx){
		return function(r){
			if (!modules[r]) throw new Error(r+' is not a module')
			return cache[r] ? cache[r].exports
							: ( cache[r]={exports:{}}, cache[r].exports=modules[r].call(cx, #{loader}, cache[r], cache[r].exports) );
		};
	})({},{},this);
"""

exports.loaderNode = (loader)-> """
	#{loader} = (function(cache,modules,cx,nativeRequire){
		return function(r){
			if (!modules[r]) return nativeRequire(r)
			return cache[r] ? cache[r].exports
							: ( cache[r]={exports:{}}, cache[r].exports=modules[r].call(cx, #{loader}, cache[r], cache[r].exports) );
		};
	})({},{},this,require);
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


exports.OFFSETS = 
	bundle: 1
	loader: 7
	module: 2











