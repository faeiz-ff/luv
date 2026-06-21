
# Modules

The module system works using the filesystem structure. All files inside a folder automatically belongs to the folder's module, and recieve symbol definitions across files, except the `main` function which is always private to the file only.

To export a name to be used across modules, use the caret '^' symbol.
unexported symbols will still be visible inside its own module.

Circular dependencies are not allowed.

```luv
# inside ./src/file1.luv

def constant = 10

fun main() {
    print("file1 ran")
}

# inside ./src/file2.luv

# use Util = "./utils/" Error! cyclic dependencies
# See below

# def constant = 20 Error! redefinition!
def ^constant2 = constant + 10

fun main() {
    print("file2 ran")
}

# inside ./src/utils/util.luv

use Src = "../src/"

def ^constant3 = Src.constant2 + 1

```

The main function that will run is in the sourced file in the cli.

The export behavior is different accross concepts:
fun main -> always file private
nom typ -> name and fields are separate exportable, if some fields are private, the raw constructor is private
all other typ (except nom), fun, and def -> if name is public, all of its behavior are public 
namespaces -> can be extended inside the module, with its private/public sections, otherwise readonly outside of module
