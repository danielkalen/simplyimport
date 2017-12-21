require('./sugar')

RegExp::test = do ()-> # RegExp::test function patch to reset index after each test
	origTestFn = RegExp::test
	return ()->
		result = origTestFn.apply(@, arguments)
		@lastIndex = 0
		return result


# Promise.onPossiblyUnhandledRejection (err, promise)->
# 	console.error formatError(err)