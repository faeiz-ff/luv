
# Tuple

`tup` is tuple types, it represents an ordered collection of type(s). Tuple bindings are automatically `def`inite. 
A literal of tup can be made using the object notation but with no ids, separated by commas.

```luv
fun main() {
    var a tup{int int int} = { 1 ,2, 3 }
    var b tup{int str int} = { 1, "a", true }

    var thing str = a(1)
    var cond bol = a(2)

    # a(1) = 10  Error!
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
    var foo = Foo.{ 1, "a", true }

    var v = vec.{1} # the main way to construct a vec or arr
}
```

tuple can also be destructured at the var/def level

```luv
fun main() {
    var { num, name, cond } = { 10, "zie", true }

    for var { i, num } in vec.{1, 2, 3}.iter().enumerate() {
        print((i + num).toStr())
    }
}
```







