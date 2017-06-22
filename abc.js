(function e(t,n,r){function s(o,u){if(!n[o]){if(!t[o]){var a=typeof require=="function"&&require;if(!u&&a)return a(o,!0);if(i)return i(o,!0);var f=new Error("Cannot find module '"+o+"'");throw f.code="MODULE_NOT_FOUND",f}var l=n[o]={exports:{}};t[o][0].call(l.exports,function(e){var n=t[o][1][e];return s(n?n:e)},l,l.exports,e,t,n,r)}return n[o].exports}var i=typeof require=="function"&&require;for(var o=0;o<r.length;o++)s(r[o]);return s})({1:[function(require,module,exports){
module.exports = require('sm-module');
},{"sm-module":2}],2:[function(require,module,exports){
(function (REqUire) {
REqUire = (function (cache, modules) {
return function (r) {
if (!modules[r]) throw new Error(r + ' is not a module');
return cache[r] ? cache[r].exports : ((cache[r] = {
exports: {}
}, cache[r].exports = modules[r](REqUire, cache[r], cache[r].exports)));
};
})({}, {
0: function (REqUire, module, exports) {
exports.a = REqUire(1)
exports.b = "def-value"
exports.c = "gHi-value"
exports.d = (function(){
	return REqUire(4) ? REqUire(4).default : REqUire(4)
})()
exports.other = REqUire('other-module');
return module.exports;
},
4: function (REqUire, module, exports) {
exports.default = jkl = 'jkl-value';
exports.__esModule=true;
return module.exports;
},
1: function (REqUire, module, exports) {
module.exports = 'abc-value';;
return module.exports;
}
});
return REqUire(0);
}).call(this, null);

},{}]},{},[1]);