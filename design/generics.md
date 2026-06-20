
# Generics

Generics or parameterized types may only be declared in `fit`, `nom`, or `tag` types, and also in `fun`.
Generics by itself is not a complete type and cant be used as a type, unless its parameters are fulfilled.
Generic fulfillment are placed in square brackets.

```luv
typ Box nom[T any] {
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
