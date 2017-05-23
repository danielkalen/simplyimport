Promise = require 'bluebird'
promiseBreak = require 'p-break'
replaceAsync = require 'string-replace-async'
streamify = require 'streamify-string'
getStream = require 'get-stream'
PATH = require 'path'
chalk = require 'chalk'
extend = require 'extend'
globMatch = require 'micromatch'
Parser = require 'esprima'
REGEX = require './regex'
helpers = require './helpers'
consoleLabels = require './consoleLabels'


class File
	constructor: (@task, state)->
		extend(@, state)
		@importedCount = 0
		@importStatements = []
		@importStatements.es6 = []
		@importStatements.custom = []
		@badImports = []
		@importMemberRefs = []
		@lineRefs = []
		@orderRefs = []
		@ignoreRanges = []
		@contentOriginal = @content
		@contentLines = @content.split(REGEX.newLine)
		@ID = ++@task.currentID
		
		if @isEntry or @isExternalEntry
			
			if  @pkgTransform = @pkgFile.browserify?.transform
				@pkgTransform = [@pkgTransform] if helpers.isValidTransformerArray(@pkgTransform)


		return @task.cache[@filePath] = @task.cache[@hash] = @



	checkIfIsThirdPartyBundle: ()->
		### istanbul ignore next ###
		@isThirdPartyBundle =
			@content.includes('.code="MODULE_NOT_FOUND"') or
			@content.includes('__webpack_require__') or
			@content.includes('System.register') or 
			@content.includes("' has not been defined'") or
			REGEX.moduleCheck.test(@content) or
			REGEX.defineCheck.test(@content) or
			REGEX.requireCheck.test(@content)

		@hasThirdPartyRequire = @isThirdPartyBundle and
			not REGEX.requireArg.test(@content) and
			REGEX.commonJS.validRequire.test(@content)


	collectRequiredGlobals: ()-> if not @isThirdPartyBundle
		@task.emit('requiredGlobal', 'global') if REGEX.vars.global.test(@content) and not REGEX.globalCheck.test(@content)
		@task.emit('requiredGlobal', 'process') if REGEX.vars.process.test(@content) and not REGEX.processRequire.test(@content) and not REGEX.processDec.test(@content)
		@task.emit('requiredGlobal', '__dirname') if REGEX.vars.__dirname.test(@content)
		@task.emit('requiredGlobal', '__filename') if REGEX.vars.__filename.test(@content)
		return


	collectIgnoreRanges: ()-> if @options.scan isnt false
		currentRange = null
		@content.replace REGEX.ignoreStatement, (m, charIndex)=>
			if currentRange
				currentRange.end = charIndex
				@ignoreRanges.push(currentRange)
				currentRange = null
			else
				currentRange = start:charIndex
			return
		
		if currentRange
			currentRange.end = @content.length
			@ignoreRanges.push(currentRange)


	determineType: ()->
		if not REGEX.export.test(@content) and not REGEX.commonJS.export.test(@content)
			@type = 'inline'
		else
			@type = 'module'


	findCustomImports: ()->
		@content.replace REGEX.customImport, (entireLine, priorContent='', importKeyword, conditions, whitespace='', childPath, trailingContent='', offset)=>
			statement = {range:[], source:@}
			statement.conditions = conditions.split(REGEX.commaSeparated) if conditions
			statement.target = helpers.cleanImportPath(childPath)
			statement.range[0] = offset + priorContent.length
			statement.range[1] = statement.range[0] + importKeyword.length + (if conditions then 2 else 0) + whitespace.length + childPath.length
			
			@importStatements.custom.push(statement)


	findES6Imports: ()->
		@content.replace REGEX.es6Import, (entireLine, importKeyword, metadata, defaultMember='', members='', childPath, offset)=>
			statement = {range:[], source:@}
			statement.members = if members then members
			statement.defaultMember = defaultMember
			statement.target = helpers.cleanImportPath(childPath)
			statement.range[0] = offset
			statement.range[1] = offset + entireLine.length
			
			@importStatements.es6.push(statement)


	customImportsToCommonJS: ()->
		for statement in @importStatements.custom
			body = "'#{statement.target}'"
			body += ", [#{statement.conditions.map((i)-> '"'+i+'"').join(',')}]" if statement.conditions
			commonSyntax = "require(#{body})"
			@content = @content.slice(0,statement.range[0]) + commonSyntax + @content.slice(statement.range[1])
			statement.range[1] = statement.range[0] + commonSyntax.length # Update end offset of range

		return


	ES6ImportsToCommonJS: ()->
		for statement in @importStatements.es6
			body = "'#{statement.target}', null"
			body += ", #{if statement.defaultMember then '"'+statement.defaultMember+'"' else 'null'}"
			body += ", #{if statement.members then statement.members else 'null'}"
			commonSyntax = "require(#{body})"
			@content = @content.slice(0,statement.range[0]) + commonSyntax + @content.slice(statement.range[1])
			statement.range[1] = statement.range[0] + commonSyntax.length # Update end offset of range

		return


	applyAllTransforms: (force=@isEntry)-> if @type is 'module' or force
		Promise.bind(@)
			.then @applySpecificTransforms
			.then(@applyPkgTransforms if @isEntry or @isExternalEntry)
			.then(@applyGlobalTransforms unless @isEntry)


	applySpecificTransforms: ()->
		Promise.bind(@)
			.then ()->
				transforms = @options.transform or []
				transforms.unshift('tsify') if @fileExt is 'tn' and not transforms.includes('tsify')
				transforms.unshift('coffeeify') if @fileExt is 'coffee' and not transforms.includes('coffeeify')
				promiseBreak(@content) if not transforms.length
			
			.then (transforms)->
				@applyTransforms(@content, transforms, PATH.resolve(@pkgFile.dirPath,'node_modules'))

			.catch promiseBreak.end
			.then (@content)->


	applyPkgTransforms: ()->
		Promise.resolve(@pkgTransform).bind(@)
			.tap (transform)-> promiseBreak(@content) if not transform
			.filter (transform)->
				name = if typeof transform is 'string' then transform else transform[0]
				return name.toLowerCase() isnt 'simplyimportify'

			.then (transforms)->
				@applyTransforms(@content, transforms, PATH.resolve(@pkgFile.dirPath,'node_modules'))

			.catch promiseBreak.end
			.then (@content)->


	applyGlobalTransforms: ()->
		Promise.bind(@)
			.then ()->
				transforms = @task.options.globalTransform
				promiseBreak(@content) if not transforms?.length
			
			.then (transforms)->
				@applyTransforms(@content, transforms, PATH.resolve(@pkgFile.dirPath,'node_modules'))

			.catch promiseBreak.end
			.then (@content)->



	applyTransforms: (content, transforms, useFullPath)->
		Promise.resolve(transforms)
			.map (transform)-> helpers.resolveTransformer(transform, useFullPath)
			.reduce((content, transformer)=>
				filePath = if useFullPath then @filePath else PATH.basename(@filePath)
				transformOpts = extend {_flags:@task.options}, transformer.opts
			
				Promise.resolve()
					.then ()=> getStream streamify(content).pipe(transformer.fn(filePath, transformOpts, @))
					.tap ()=>
						if transformer.name is 'coffeeify' or transformer.name is 'tsify'
							@fileExt = 'js'
							@filePath = helpers.changeExtension(@filePath, 'js')
							@filePathSimple = helpers.changeExtension(@filePathSimple, 'js')
				
			, content)



	attemptASTGen: ()->
		shouldGenAST =
			@fileExt is 'js' and (
				@importStatements.custom.length or
				@importStatements.es6.length or
				REGEX.export.test(@content) or
				REGEX.commonJS.export.test(@content)
			)

		if shouldGenAST
			try
				@AST = Parser.parse(@content, tolerant:true, sourceType:'module', range:true)
			catch err
				@task.emit 'astParseError', @, err



	collectImports: (AST=@AST)->
		switch
			when AST
				require('esprima-walk') AST, (node)=>
					if  node.type is 'CallExpression' and
						node.callee.type is 'Identifier' and
						node.callee.name is 'require' and
						node.arguments.length and
						typeof node.arguments[0].value is 'string'
							[target, conditions, defaultMember, members] = node.arguments
							target = helpers.cleanImportPath(target.value).split('$')
							statement = {range:node.range, source:@}
							statement.target = target[0]
							statement.extract = target[1]
							statement.conditions = if conditions?.elements then conditions.elements.map (element)-> element.value
							statement.members = if members and members.value then helpers.parseMembersString(members)
							statement.defaultMember = if defaultMember and defaultMember.value then defaultMember.value
							@importStatements.push(statement)


			when @fileExt is 'pug' or @fileExt is 'jade'
				@content.replace REGEX.pugImport, (entireLine, priorContent='', keyword, childPath, offset)=>
					statement = {range:[], source:@}
					statement.target = helpers.cleanImportPath(target.value)
					statement.priorContent = priorContent
					statement.range[0] = offset + priorContent.length
					statement.range[1] = offset + entireLine.length
					@importStatements.push(statement)


			when @fileExt is 'sass' or @fileExt is 'scss'
				@content.replace REGEX.cssImport, (entireLine, priorContent='', keyword, childPath, offset)=>
					statement = {range:[], source:@}
					statement.target = helpers.cleanImportPath(target.value)
					statement.priorContent = priorContent
					statement.range[0] = offset + priorContent.length
					statement.range[1] = offset + entireLine.length
					@importStatements.push(statement)


		return @importStatements










module.exports = File