Promise = require 'bluebird'
promiseBreak = require 'promise-break'
chalk = require 'chalk'
extend = require 'extend'
helpers = require '../helpers'
debug = require('../debug')('simplyimport:file')


exports.applyAllTransforms = ()->
	@allTransforms = [].concat @options.transform, @task.options.transform, @task.options.globalTransform, @pkgTransform

	Promise.resolve(@content).bind(@)
		.tap ()-> debug "start applying transforms #{@pathDebug}"
		.then @applySpecificTransforms							# ones found in "simplyimport:specific" package.json field
		.then @applyPkgTransforms								# ones found in "browserify.transform" package.json field
		.then(@applyRegularTransforms unless @isExternal)		# ones provided through options.transform (applied to all files of entry-level package)
		.then @applyGlobalTransforms							# ones provided through options.globalTransform (applied to all processed files)
		.then (result)-> @content = result
		.tap ()-> debug "done applying transforms #{@pathDebug}"


exports.applySpecificTransforms = (content)->
	Promise.resolve(content).bind(@)
		.then (content)->
			transforms = @options.transform
			forceTransform = switch
				when @pathExt is 'cson'		and not @allTransforms.includes('csonify') 			then 'csonify'
				when @pathExt is 'yml'		and not @allTransforms.includes('yamlify') 			then 'yamlify'
				when @pathExt is 'ts'		and not @allTransforms.includes('tsify-transform') 	then 'tsify-transform'
				when @pathExt is 'coffee'	and not @allTransforms.some((t)-> t?.includes('coffeeify')) then 'coffeeify-cached'
			
			transforms.unshift(forceTransform) if forceTransform
			promiseBreak(content) if not transforms.length
			return [content, transforms]
		
		.spread (content, transforms)->
			@applyTransforms(content, transforms, 'specific')

		.catch promiseBreak.end


exports.applyPkgTransforms = (content)->
	Promise.resolve(@pkgTransform).bind(@)
		.tap (transform)-> promiseBreak(content) if not transform or @options.skip
		.filter (transform)->
			name = if typeof transform is 'string' then transform else transform[0]
			return not name.toLowerCase().includes 'simplyimport/compat'
		
		.then (transforms)-> [content, transforms]
		.spread (content, transforms)->
			@applyTransforms(content, transforms, 'package')

		.catch promiseBreak.end


exports.applyRegularTransforms = (content)->
	Promise.bind(@)
		.then ()->
			transforms = @task.options.transform
			promiseBreak(content) if not transforms?.length or @options.skipTransform
			return [content, transforms]
		
		.spread (content, transforms)->
			@applyTransforms(content, transforms, 'options')

		.catch promiseBreak.end


exports.applyGlobalTransforms = (content)->
	Promise.bind(@)
		.then ()->
			transforms = @task.options.globalTransform
			promiseBreak(content) if not transforms?.length or @options.skipTransform
			return [content, transforms]
		
		.spread (content, transforms)->
			@applyTransforms(content, transforms, 'global')

		.catch promiseBreak.end



exports.applyTransforms = (content, transforms, label)->
	lastTransformer = null
	prevContent = content
	
	Promise.resolve(transforms).bind(@)
		.tap @timeStart
		.filter (transform)-> not @task.options.ignoreTransform.includes(transform)
		.map (transform)->
			lastTransformer = name:transform, fn:transform
			helpers.resolveTransformer(transform, @)
		
		.reduce((content, transformer)->
			lastTransformer = transformer
			flags = extend {}, @task.options
			flags.debug = true if flags.sourceMap
			transformOpts = extend {_flags:flags}, transformer.opts
			prevContent = content

			Promise.bind(@)
				.tap ()-> debug "applying transform #{chalk.yellow transformer.name} to #{@pathDebug} (from #{label} transforms)"
				.then ()-> helpers.runTransform(@, content, transformer, transformOpts)
				.then (content)->
					return content if content is prevContent
					if transformer.name.includes(/coffeeify|tsify-transform/)
						@pathExt = 'js'
					else if transformer.name.includes(/csonify|yamlify/)
						@pathExt = 'json'
						content = content.replace /^module\.exports\s*=\s*/, ''
						content = content.slice(0,-1) if content[content.length-1] is ';'
					
					if @pathExt isnt @original.pathExt
						@pathAbs = helpers.changeExtension(@pathAbs, @pathExt)
					
					return @extractSourceMap(content)
			
		, content)
		.catch (err)->
			@task.emit 'TransformError', @, err, lastTransformer
			return prevContent

		.tap @timeEnd









