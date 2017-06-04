registerModule = (moduleName)->
	Object.defineProperty module.exports, moduleName,
		configurable: true
		get: ()->
			result = require "./#{moduleName}"
			delete module.exports[moduleName]
			module.exports[moduleName] = result
			return result

registerModule 'getNormalizedDirname'
registerModule 'simplifyPath'
registerModule 'changeExtension'
registerModule 'isMixedExtStatement'
registerModule 'relatedExtensions'
registerModule 'lineCount'
registerModule 'isLocalModule'
registerModule 'getDirListing'
registerModule 'resolveFilePath'
registerModule 'resolveModulePath'
registerModule 'resolvePackagePaths'
registerModule 'resolveTransformer'
registerModule 'safeRequire'
registerModule 'isValidTransformerArray'
registerModule 'randomVar'
registerModule 'prepareMultilineReplacement'
registerModule 'accumulateRangeOffsetAbove'
registerModule 'accumulateRangeOffsetBelow'
registerModule 'newImportStatement'
registerModule 'newExportStatement'
registerModule 'collectRequires'
registerModule 'collectImports'
registerModule 'collectExports'
registerModule 'walkTokens'
registerModule 'tokenWalker'
registerModule 'namedError'
registerModule 'blankError'
registerModule 'annotateErrLocation'
registerModule 'exportLastExpression'