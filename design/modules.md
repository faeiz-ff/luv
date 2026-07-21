
# Modules

The module system works using the filesystem structure. To export a name to be used across modules, use the caret '^' symbol.
Unexported symbols will still be visible inside its own module. `main` function are always private to its own file, 
and cannot be exported, any file that is run by the interpreter will execute its file's main function.

Circular dependencies are not allowed.

All files are singular module by default, with their filename as the module name. 
They can import anything inside their own folder. To import, use the `use` keyword.

```luv
# inside src/file1.luv

def ^importantNumber = 1

# inside src/file2.luv

use file1

def hiddenNumber = file1.importantNumber + 1
```

`use` can alias a module name (only inside the same folder) if needed.

```luv
use importedFile = "1"
```

## Multi-file module

A file can join other module inside its own folder using the `mod` keyword with the same module name across the files. 
Redefinition of symbols is not allowed inside the same module, with the exception of the `main` function (file-private always).

```luv
#inside src/file1.luv

mod utils

def a = 10

#inside src/file2.luv

mod utils

# def a = 20 Error!

def b = a + 10
```

## Subfolder Module

A Subfolder by default will have public access with their own, unless they have a same-name-module-file inside it.
This file controls the interface of the subfolder. It can reexport module names or even cherry pick names to export.
The file must have the same name as its parent folder name, and belongs has no `mod`.

```luv
#inside src/utils/file1.luv

def ^a = 1

#inside src/utils/tool.luv

fun ^id[T any](t T) T { return t }

#inside src/utils/utils.luv

use ^file = file1
use tool

def ^funId = tool.id

#inside src/main.luv

use file = utils.file

#inside src/build.luv

use utils

def a = utils.funId(1)

```

In the above case, "src/main.luv" only imports the file "src/utils/file1" and not anything else.
And "src/build.luv" imports everything exported in "src/utils/utils.luv" including the "file" module and funId

a subfolder name cannot clash with another filename beside it.

