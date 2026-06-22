
# Rest operator

## Variadic

Functions can recieve variadic number of arguments using the rest '..' modifier before the last parameter identifier. Stored as the built in `vec` type.

```luv
fun sum(..args int) {
    var total = 0
    for var num in args {
        total += num
    }
    return total
}
```

## Spread

Objects can assign other objects attributes with the rest '..' operator inside object literals. Attributes can be reassigned for modification if it is done after the rest operator.

```luv
fun main() {
    var foo = {
        a = 10
        b = 20
    }

    var bar = {
        ..foo
        a = 0
    } # a = 0, b = 20
}
```

multiple spread will overwrite each other values if clashed, but will error if the types don't match.

Function call can also have spread on a built-in `vec` type, for matching a variadic function type.

```luv
fun main() {
    var v = vec[int].new()
    v.append(1)
    v.append(2)
    v.append(3)
    
    var m = sum(..v)
}
```

