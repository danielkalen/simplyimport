

module.exports = randomVar = ()->
	"_s#{Math.floor((1+Math.random()) * 100000).toString(16)}"