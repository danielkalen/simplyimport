# SimplyImport
[![Build Status](https://travis-ci.org/danielkalen/simplyimport.svg?branch=master)](https://travis-ci.org/danielkalen/simplyimport)
[![Coverage](.config/badges/coverage.png?raw=true)](https://github.com/danielkalen/simplyimport)
[![Code Climate](https://codeclimate.com/repos/57c332508cc944028900237a/badges/6b3dda1443fd085a1d3c/gpa.svg)](https://codeclimate.com/repos/57c332508cc944028900237a/feed)
[![NPM](https://img.shields.io/npm/v/simplyimport.svg)](https://npmjs.com/package/simplyimport)
[![NPM](https://img.shields.io/npm/dm/simplyimport.svg)](https://npmjs.com/package/simplyimport)

**Features Summary**
- Takes a file or its contents, scans for imports, and replaces the import statements inline with the imported file's content.
- Can import JavaScript files into CoffeeScript files (and vise-versa).
- Can import relative/absolute paths & NPM modules (with `browser` field support in `package.json`)
- Supports ES6-syntax imports (extended with additional features/functionality).
- Supports CommonJS imports (i.e. require).
- Supports ES6 and CommonJS exports.
- Supports conditional imports.
- Supports duplicate imports (i.e. a single file that's imported in multiple places).
- Supports [browserify-style](https://github.com/substack/browserify-handbook#transforms) [plugins & transforms](https://github.com/substack/node-browserify/wiki/list-of-transforms) that can be applied to the final bundle file, each imported file, or to specific individual files.
- Can import UMD and third-party-bundled modules (without replacing its require statements).
- Adds closures/different scopes only for duplicate imports and files that have exports.
- **Adds zero overhead** to processed files (with the exception of a few bytes for duplicate imports).
- Most built-in node modules are shimmed (non IO-related ones).
- Node global variables (`__filename`/`__dirname`/`global`|`process`) are shimmed.


## Installation
```bash
npm install simplyimport --save
```


## Example Usage
```javascript
/*--- fileA.js ---*/
var fileA = 'A';

/*--- fileB.js ---*/
'B'

/*--- fileC.js ---*/
var inner = 'C';
module.exports = inner;

/*--- fileD.js ---*/
export let innerVar = 'D';


/*--- main.js ---*/
import 'fileA.js'
var fileB = import fileB.js;
var fileC = require('fileC')
import {innerVar as fileD} from './fileD.js'
```

**Output**
```javascript
var fileA = 'A';
var fileB = 'B';
var fileC = 'C'; // Real output will have an IIFE returning this value
var fileD = 'D'; // Real output will have an IIFE returning this value
```


# Usage
### Import/Export directive syntax
**`Import (ES6)`** - `import [<conditions>] [<defaultMember> {<members>} from] <filepath/module>`

**`Import (CommonJS)`** - `require(<filepath/module>)`

**`Export (ES6)`** - `export [default] [{<members>}]`

**`Export (CommonJS)`** - `module.exports = ` OR `module.exports[<member>] = `OR `exports[<member>] = `

```javascript
//--- Imports
import 'parts/someFile.js'
import 'parts/someFile.coffee'
import parts/someFile
import defaultMember from parts/someFile
import * as customExports from parts/../parts/someFile
import {readFile, readdir as readDir} from 'fs'
import [conditionA, conditionB] parts/someFile.js
var foo = import parts/someLibrary.js
require('../parts/someFile')
require('npmModule')

//--- Exports
export var abc = '123'
export let def = '456'
export const ghi = '789'
export default function(){}
export function fnName(){}
export {aaa, bbb as BBB, ccc}
exports = {'aaa':aaa, 'BBB':bbb}
module.exports['ddd'] = 'ddd'
module.exports.eee = 'eee'
```


# CLI API
```
simplyimport -i <input> -o <output> -[c|u|r|p|s|t|C]
```

**Options**
```
-i, --input                    Path of the file to compile (stdin will be used if omitted)
-o, --output                   Path of file/dir to write the compiled file to (stdout will be used if omitted)
-c, --conditions               Conditions list that import statements which have conditions should match against. '*' will match all conditions. Syntax: -c condA [condB...]
-r, --recursive                Follow/attend import statements inside imported files, (--no-r to disable) (default:true)
-p, --preserve                 Invalid import statements should be kept in the file in a comment format (default:false)
-t, --transform                Path or module name of the browserify-style transform to apply to the bundled file
-g, --globalTransform          Path or module name of the browserify-style transform to apply each imported file
-C, --compile-coffee-children  If a JS file is importing coffeescript files, the imported files will be compiled to JS first (default:false)
-h                             Show help
--version                      Show version number
```


# Node.JS API
#### `SimplyImport(filePath|content, [options], [state])`
Takes the provided path/content, scans and replaces all import/require statements, and returns a promise which will be resolved with the result as a string.

Arguments:
  - `filePath|content` - a relative/absolute file path or the file's content. If the file's content is passed state.isStream must be set to true for proper parsing.

  - `options` (optional) - an object containing some/all of the following default options:
    - `uglify [false]` uglify/minify the processed content before returning it.
    - `recursive [true]` Follow/attend import statements inside imported files.
    - `preserve [false]` Invalid imports (i.e. unmatched conditions) should be kept in the file in a comment format.
    - `dirCache [true]` Cache directory listings when resolving imports that don't provide a file extension.
    - `toES5 [false]` Transpile all ES6 code present in imported files to be ES5 compatible
    - `preventGlobalLeaks [true]` Wrap the processed content in a closure to prevent variable leaks into the outer scope whenever necessary (e.g. when there are duplicate imports)
    - `compileCoffeeChildren [false]` If a JS file is importing coffeescript files, the imported files will be compiled to JS first
    - `conditions [array]` Array that import statements which have conditions should match against. '*' will match all conditions.
    - `transform [array]` String or array of transforms to apply to the final bundled file's content in order (after processing all imports). A transform can either be the name of an npm transform package (e.g. `coffeeify`), a relative file path (e.g. `./transforms/minify.js`), or a [transform function](https://github.com/substack/browserify-handbook#writing-your-own). Module-specific options can be passed using browserify-style array syntax like so: `['coffeeify', {bare:true, header:true}]`.
    - `globalTransform [array]` Same as `options.transform`, but instead will be applied to all imported files instead of to the final bundled file.
    - `fileSpecific [object]` An object map in the form of `<glob|filepath|module>:<options>` in which each file matching the provided glob or path will have the supplied options be applied only to that file *in addition* to any global transforms supplied. Availble options:
      - `transform [array]` Same as `options.transform`.
      - `scan [true]` Whether or not the matching file should be scanned for imports/exports.
      Example: `"*.coffee": {transform:['coffeeify', {header:true}]}` 

  - `state` (optional) - an object containing some/all of the following default properties:
    - `isStream [false]` Indicates the provided input is the file's content.
    - `isCoffee [false]` Indicates the path/content is CoffeeScript (only required when `state.isStream` is true).
    - `context [filePath/process.cwd()]` The base dir in which relative paths/NPM modules will be resolved form. If a file path is provided the context is taken from the path and if direct content is passed `process.cwd()` will be used.


#### `SimplyImport.scanImports(filePath|content, [options])`
Takes the provided path/content, scans all import/require statements, and returns a promise which will be resolved with an array of all imports discovered.

Arguments:
  - `filePath|content` - a relative/absolute file path or the file's content. If the file's content is passed options.isStream must be set to true for proper parsing.


  - `options` (optional) - an object containing some/all of the following default properties:
    - `isStream [false]` Indicates the provided input is the file's content.
    - `isCoffee [false]` Indicates the path/content is CoffeeScript (only required when `options.isStream` is true).
    - `withContext [false]` Return filepaths with their context (i.e. absolute paths).
    - `context [filePath/process.cwd()]` The base dir in which relative paths/NPM modules will be resolved form. If a file path is provided the context is taken from the path and if direct content is passed `process.cwd()` will be used.
    - `pathOnly [false]` Return just the imported file's path for each entry in the result array.

```javascript
/*--- main.js ---*/
import [conditionA, conditionB] 'fileA.js'
var fileB = import './someDir/fileB.js'
require('fileC.js')

/*--- App ---*/
SimplyImport.scanImports('./main.js').then(function(imports){
/* imports === [
    {
      path: 'fileA.js',
      entireLine: 'import [conditionA, conditionB] \'fileA.js\'',
      priorContent: '',
      spacing: '',
      conditions: ['conditionA', 'conditionB']
    },
    {
      path: 'someDir/fileB.js',
      entireLine: 'var fileB = import \'./someDir/fileB.js\'',
      priorContent: 'var fileB = ',
      spacing: ' ',
      conditions: null
    },
    {
      path: 'fileC.js',
      entireLine: 'require(\'fileC.js\')',
      priorContent: '',
      spacing: '',
      conditions: null
    }
  ]*/  
})
```


# Compability shims
The following NodeJS-native modules will be shimmed when imported either via the `import` or `requite` statement:
  - assert
  - zlib
  - buffer
  - console
  - constants
  - crypto
  - domain
  - events
  - https
  - os
  - path
  - process
  - punycode
  - querystring
  - http
  - string_decoder
  - stream
  - timers
  - tty
  - url
  - util
  - vm

The following NodeJS globals will be shimmed/defined:
  - process
  - global (alias to `window`)
  - __filename (file path of the currently executing file relative to the current working dir)
  - __dirname (directory path of the currently executing file relative to the current working dir)


# Package.json field
File-specific options can be provided via `package.json`'s `"simplyimport"` field. When running SimplyImport from the CLI, the current working dir will be scanned for a `package.json` file and if found its `"simplyimport"` field will be used for file-specific options. Example:
```javascript
{
  //...
  "simplyimport": {
    "*.coffee": {
      "transform": ["coffeeify", {"header":true}]
    },
    "src/js/*.js": [["babelify", {"preset":"latest"}], "uglifyify"]
  }
}
```


# Case-specific notes
### Returning the last statement of exprot-less imports
If an import statement is assigned to a variable its content will be modified to return the last expression if it doesn't have any exports.
```javascript
/*--- childFile.js ---*/
var abc = '123';
var def = '456';

/*--- mainA.js ---*/
import 'childFile.js'

/*--- mainB.js ---*/
var importedContent = import 'childFile.js'
```

**Output**
```javascript
/*--- mainA.js ---*/
var abc = '123';
var def = '456';

/*--- mainB.js ---*/
var importedContent = (function(){
  var abc = '123';
  var def = '456';
  return def;
})()

```


### Commented imports/requires
If SimplyImport encounters a commented import/require, the import will be ignored and will not be scanned.
```javascript
// import 'someFile.js'
// require('someFile.js')
var another = require('anotherFile.js');
```

**Output**
```javascript
// import 'someFile.js'
// require('someFile.js')
var another = /*contents of anotherFile.js*/;
```


### Module/filepath precedence
SimplyImport will first attempt to resolve supplied import paths as NPM packages and only if no package was found will it proceed to resolving as regular files. This means that if you have a NPM package installed named *uniq* and have a file called *./uniq.js*, `require('uniq')` will resolve to the NPM package if it's installed, otherwise the local file will be used.


### ES6-syntax import statements can be wrapped in parenthesis and used in any scope
Regular ES6 imports are only allowed in the outer-most scope and may not be placed inside closures or block statements, but SimplyImport allows import statements to be placed in any place you desire.
```javascript
/*--- func.js ---*/
function(a,b){return a*b}

/*--- main.js ---*/
var result = (import 'func.js')(2,5) // Will resolve to equal 10 in runtime.
```




