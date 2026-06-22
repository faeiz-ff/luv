
# Scope Returns

There are 3 scoped blocks to return a value from, functions, for blocks, and if/match blocks.

if/match blocks can use the shorthand arrow '->' then expr or `yield` in a block to return an expression, 
for blocks can use `break` to return an expr, and functions use `return` to return an expr.

These keywords will return an expression at the nearest valid scope. In a `for` block, `yield` will returns if the `for` block is inside of an if block, and so on.

```luv
fun main() {
    var a = for {
        if false {
            print("oh no")
        } else {
            break 1
        } 
        break 2
    }

    var b = if true {
        for {
            yield 1
        }
    } else {
        for {
            yield 2
        }
    }

    var a = for {
        break for {
            break for {
                if true {
                    return 0
                }
                break 1
            }
        }
    }
}
```
