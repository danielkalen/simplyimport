# SimplyImport
The `require` module system is great and all, but sometimes all we want to do is just import a separate file as is like it was written inside the importing file without the hassle of writing annoying `module.exports` and `require` declarations. After using SASS's @import and PHP's include/require, I realized the importance of modularity and keeping code files small for the sake of usability, readability, and our sanity. Browserify, AMD, CommonJS, etc. are all great solutions for javascript modularity but sometimes they are just way too complicated and require way too much work than it should in order to implement simple modularity.

Keep in mind that the aformentioned module systems **are probably more semantic** and would probably be considered more profesisonal, but this import concept takes a more simplictic approach that is easier and faster to implement and is just offered as an **addition** to your current module workflow, not necessarily a replacement.

With SimplyImport you can:

* implement a simpler and faster modular system than the currently available methods.
* split huge files into bits and pieces to keep your sanity in place.
* eliminate the need to search through thousands of lines everytime you need to reference/change something.
* create different versions of the same file with conditional imports
* and much more...


Usage:
------
**Directive Syntax**
```
// @import {<conditions separated by commas>} <filepath (quotes/ext optional)>
```

**Command Line**
```
simplyimport -i <input> -o [<output>|<outputdir>] -[u|s|n]
```

**Node Module**
```javascript
var SimplyImport = require('simplyimport');

// Compile by filename (writes compiled file to the second argument)
SimplyImport('src/foo.js', 'dist/foo.compiled.js', {shouldUglify: true});

// Compile by string (returns compiled string)
fs.readFile('foo/bar.js', function(err, data){
  var compiled = SimplyImport(data);
  console.log(compiled) // Logs out the compiled data with all its @import directives attended.
});
```

**Command Line Options:**

```bash
-i, --input         Path of the file to compile. Can be relative or absolute.
                                                           [string] [required]
-o, --output        Path to write the compiled file to. Can be a file, or
                    directory. If omitted the compiled result will be written
                    to stdout.                                        [string]
-s, --stdout        Output the compiled result to stdout. (Occurs by default
                    if no output argument supplied.)                 [boolean]
-u, --uglify        Uglify/minify the compiled file.[boolean] [default: false]
-n, --notrecursive  Do not attend/follow @import directives inside imported
                    files.                          [boolean] [default: false]
-p, --preserve      @import directives that have unmatched conditions should
                    be kept in the file.            [boolean] [default: false]
-c, --conditions    Specify the conditions that @import directives with
                    conditions should match against. Syntax: -c condA condB
                    condC...                                           [array]
-h, --help          Show help                                        [boolean]
```






Example:
------
#### Command Line:
```
simplyimport -i src/main.js -o dist/main.js -c browserVersionOnly simpleVersion

simplyimport -i src/main.coffee -o dist/main.coffee -u // Supports Coffeescript
```

#### Node module:
*nesteddir/variable1.js*
```javascript
var variable1 = 'foo';
```

*nesteddir2/variable2.js*
```javascript
var variable2 = 'bar'; // will not import because of the unmatched conditions
```

*nesteddir3/variable3.js*
```javascript
var variable3 = 'baz';
```

*nesteddir4/variable4.js*
```javascript
var variable4 = 'qux';
```

*main.js*
```javascript
var concatStrings = function(arg1, arg2){return arg1+' '+arg2};

// @import 'nesteddir/variable1.js'
// @import {nodeVersionOnly} nesteddir2/variable2.js
// @import {browserVersionOnly} ../../nesteddir3/variable3.js

concatStrings(variable1, variable3);

// @import {browserVersionOnly, simpleVersion} nesteddir4/variable4

concatStrings(variable1, variable4);
```

**Compiled** *main.js*
```javascript
var concatStrings = function(arg1, arg2){return arg1+' '+arg2};

var variable1 = 'foo';
var variable3 = 'baz';

concatStrings(variable1, variable3); // outputs "foo baz"

var variable4 = 'qux';

concatStrings(variable1, variable4); // outputs "foo qux"
```
