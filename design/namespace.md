
# Namespace

A namespace can be created by all typedefs. If a bare namespace is needed, use `nil` or `[]`

Unlike objects, namespaces are extensible (inside module). This allows outside code to attach a new thing, like methods that satisfies a `fit`, into an already existing namespace of a nominal type, as long as the names dont clash (no shadowing).

A `def` statement is used for attaching constant value into a identifier. At the top level, a `def` can be namespaced, its the only way to extend namespace. a defined 'variable' can't be modified.


```luv
typ Math []

def Math.pi = 3.14
def Math.e = 2.71

def Math.epsilon = 0.000001

fun Math.abs(n flo) flo {
    return if n < 0 -> -n else -> n
}

fun Math.sqrt(n flo) flo {
    var guess = n
    var next = 0.0
    for {
        next = (guess + n / guess) / 2
        if Math.abs(guess - next) < Math.epsilon { break }
        guess = next
    }
    return next
}
```

The `fun` statement is just a syntactic sugar of a `def` to a lambda.

```luv
def Math.abs = fun(n flo) flo {
    return if n < 0 -> -n else -> n
}
```

A namespace can be passed around as a view of fit that follows the shape of the namespace.
the `Math` namespace up above fit into this shape.

```luv
typ MathModule fit {
    def pi      flo
    def e       flo 
    def epsilon flo
    def abs     fun(flo) flo
    def sqrt    fun(flo) flo
}

fun main() {
    var m MathModule = Math
}
```

Note that the Math namespace does own its own function, and its all defined using `def` so the bindings cannot be changed.
