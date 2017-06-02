module.exports = (message)->
	err = new Error(message or '')
	err.stack = ''
	return err