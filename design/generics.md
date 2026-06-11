
# Generics

Generics or parameterized types may only be declared in `fit`, `nom`, or `tag` types, and also in `fun`.
Generics by itself is not a complete type and cant be used as a type, unless its parameters are fulfilled.

```luv
typ Shape tag[T any] {
    Circle T
    Square T
}

fun Shape.getArea[T any](own Shape[T]) {
    return match tag shape {
        Circle radius -> radius * radius * Math.Pi
        Square length -> length * length
    }
}

fun main() {
    var shape Shape[int] = Shape.Circle.[int](10)
    var area = shape.getArea()
}
```

The syntax of generic fulfillment in the grammar position of expression is always before a call and must be preceded by a dot '.'


