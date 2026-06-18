
# View

A view is a readonly version of an object, the inner state of the object will be of readonly too. 
Readonly variable means that the object is immutable by the current binding, the actual object may possibly be mutated by outside means.
It can be constructed at the type level using '&'. A mutable object can be coerced into a view, but not the reverse.

```luv

typ Foo nom {
    bar int
} 

fun Foo.change(own Foo) {
    own.bar = 10
}

fun Foo.see(own &Foo) int {
    # own.bar = 10 Error!
    return own.bar
}

fun main() {
    var f &Foo = Foo.{
        bar = 10
    }

    f.see()    # Ok
    # f.change() Not Ok
}

```
