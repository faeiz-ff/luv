
# Generics

Generics or parameterized types may only be declared in `fit`, `nom`, or `tag` types, and also in `fun`.
Generics by itself is not a complete type and cant be used as a type, unless its parameters are fulfilled.
Generic fulfillment are placed in square brackets.

```luv
typ Box[T any] nom {
    thing T
}

fun Box.get[T any](own Box[T]) T {
    return own.thing
}

fun main() {
    var box Box[int] = Box[int].(10)
    var inside = box.get[int]()
}
```

Namespaces cannot be generic, `luv` doesnt do type monomorphization.
Instead, for methods, the functions itself may be generics.

Every generics will have a type of `generic` which needs to be fulfilled first for it to have a qualified type.
This type is internal, same as a 'type' type, cannot be accessed.
This means that a generic function cannot be typed or even used, but it could when its generics fulfilled.

```luv

typ Stringable fit {
    toStr(Own) str
}

# Not a fully qualified type
fun logger[T Stringable](thing T) T {
    print(thing.toStr())
    return thing
}

typ Int nom { item int }

fun Int.toStr(own Int) str {
    return own.item.toStr()
}

def Int.logger = logger[Int]
# Int.logger is of type fun(Int) Int

typ Logable fit {
    logger(Own) Own
}
```
