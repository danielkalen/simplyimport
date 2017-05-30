exports.iife = (args, values, body)-> """
	(function(#{args.join(',')}){
		#{if body then body else ''}
	}).call(#{['this'].concat(values).join(',')})
"""

exports.loader = ()-> """
_s$m = (function(cache,modules){
	return function(r,module){
		return cache[r] ? cache[r].exports
						: ( cache[r]={exports:{}}, modules[r](cache[r], cache[r].exports) );
	};
})({},{});
"""


exports.globalDec = ()-> """
	typeof global !== "undefined" ? global : typeof self !== "undefined" ? self : typeof window !== "undefined" ? window : {}
"""

exports.umdResult = (name)-> """
	if (typeof define === 'function' && define.umd) {
		define(function(){return _s$m(0)})
	} else if (typeof module === 'object' && module.exports) {
		module.exports = _s$m(0)
	} else {
		return this['#{name}'] = _s$m(0)
	}
"""














