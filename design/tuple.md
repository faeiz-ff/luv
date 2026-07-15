
# Tuple

Tuple types represents an ordered collection of type(s). Tuple bindings are automatically `def`inite. 
tuple are typed with brackets '[]'. Single element tuple needs a comma at the end of the type before closing square bracket.
A literal of tup can be made using the object notation but with no ids, separated by commas.
A tuple can be indexed with dot '.' followed by a number, every tuple item is typed.

```luv
fun main() {
    var a [int, int, int] = (1, 2, 3)
    var b [int, str] = (1, "a")

    var thing int = a.1
    var name str = b.2

    # a.1 = 10  Error!
}
```

tuple can also be made as arguments in nominal construction, the application order will be the field declaration order at the `nom`.

```luv
typ Foo nom {
    bar int
    baz str
    baq bol
}

fun main() {
    var foo = Foo.( 1, "a", true )
}
```

tuple can also be destructured at the var/def level

```luv
fun main() {
    var num, name, cond = ( 10, "zie", true )

    for var i, num in vec.from(1,2,3).iter().enumerate() {
        print((i + num).toStr())
    }

    if var n1, n2, n3 = ( 1,2,3 ) and n1 == 1 {
        print(n1)
    }
}
```

tuple type can be cast into a smaller element count tuple type, if the smaller type is a subtype of the larger tuple type.

```luv
fun accessFirst(thing [int,]) int {
    return thing.0
}

fun main() {
    var num1 = (1,)
    var num2 = (1, 2,)
    var num3 = (1, 2, 3,)

    accessFirst(num1)
    accessFirst(num2)
    accessFirst(num3)
}
```

tuple can also be a bound for a generic, to capture the type.

```luv
fun logThirdInt[T [any, any, int]](thing T) T {
    print(thing.2)
    return thing
}
```
