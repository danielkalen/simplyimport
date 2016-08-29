# SimplyImport
[![Build Status](https://travis-ci.org/danielkalen/simplyimport.svg?branch=master)](https://travis-ci.org/danielkalen/simplyimport)
[![Coverage](.config/badges/coverage-node.png?raw=true)](https://github.com/danielkalen/simplyimport)
[![Code Climate](https://codeclimate.com/repos/57c332508cc944028900237a/badges/6b3dda1443fd085a1d3c/gpa.svg)](https://codeclimate.com/repos/57c332508cc944028900237a/feed)

The `require` module system is great and all, but sometimes all we want to do is just import a separate file as is like it was written inside the importing file without the hassle of writing those annoying `module.exports` and `require` declarations.

After using SASS's @import and PHP's include/require, I realized the importance of modularity and keeping code files small for the sake of usability, readability, and our sanity. Browserify, AMD, CommonJS, etc. are all great solutions for javascript modularity but sometimes they are just way too complicated and require way too much work than it should in order to implement simple modularity.

Keep in mind that the aformentioned module systems **are probably more semantic** and would probably be considered more profesisonal, but this import concept takes a more simplictic approach that is easier and faster to implement and is just offered as an **addition** to your current module workflow, not necessarily a replacement.

With SimplyImport you can:

* implement a simpler and faster modular system than the currently available methods.
* split huge files into bits and pieces to keep your sanity in place.
* eliminate the need to search through thousands of lines everytime you need to reference/change something.
* create different versions of the same file with conditional imports
* and much more...


Installation:
------
```bash
npm install simplyimport
```

Usage:
------
**Directive Syntax**
```
import [<conditions>] <filepath>

examples:
    import 'parts/someFile.js'
    import 'parts/someFile.coffee'
    import parts/someFile
    import ../../parts/someFile
    import [conditionA, conditionB] parts/someFile.js
    var foo = import parts/someLibrary.js
```

**Command Line API**
```
simplyimport -i <input> -o <output> -[c|u|r|p|s|C]
```

**Command Line Options:**

```bash
-i, --input                    Path of the file to compile (relative or absolute)
-o, --output                   Path of file/dir to write the compiled file to (stdout will be used if omitted)
-c, --conditions               Conditions list that import directives which have conditions should match against. Syntax: -c condA [condB...]
-u, --uglify                   Uglify/minify the compiled file (default:false)
-r, --recursive                Follow/attend import directives inside imported files, (--no-r to disable) (default:true)
-p, --preserve                 Invalid import directives should be kept in the file in a comment format (default:false)
-s, --silent                   Suppress warnings (default:false)
-t, --track                    Prepend [commented] tracking info in the output file so that future files importing this one will know which files are already imported (default:false)
-C, --compile-coffee-children  If a JS file is importing coffeescript files, the imported files will be compiled to JS first (default:false)
-h, --help                     Show help
--version                      Show version number
```

**Module API**
```javascript
var SimplyImport = require('simplyimport');

// Option A: Pass the path of the file
var compiled = SimplyImport('src/foo.js', options); // Optional options object

// Option A: Pass the contents of the file
fs.readFile('src/foo.js', function(err, fileContents){
  var compiled = SimplyImport(fileContents, options, {isStream: true});
});
```
**Module Options**
```javascript
defaultOptions = {
  'uglify': false,
  'recursive': true,
  'preserve': false,
  'silent': false,
  'track': false,
  'conditions': [],
  'compileCoffeeChildren': false
}
```







Example:
------
*main.js*
```javascript
import 'someDir/variable1.js'
import [conditionA] someDir/variable2.js
import [conditionB] ../../someDir/variable3.js
import [conditionB, conditionC] someDir/variable4

console.log(variable1+' '+variable2);
console.log(variable1+' '+variable4);
```

*someDir/variable1.js*
```javascript
var variable1 = 'A';
```

*someDir/variable2.js*
```javascript
var variable2 = 'B'; // will not import because of the unmatched conditions
```

*someDir/variable3.js*
```javascript
var variable3 = 'C';
```

*someDir/variable4.js*
```javascript
var variable4 = 'D';
```

**Process via SimplyImport**
```bash
simplyimport -i main.js -o main.compiled.js -c 'conditionB' 'conditionC'
```

*main.**compiled**.js*
```javascript
var variable1 = 'A';
var variable2 = 'B';

var variable4 = 'D';

console.log(variable1+' '+variable2); // logs "A B"
console.log(variable1+' '+variable4); // logs "A D"
```
