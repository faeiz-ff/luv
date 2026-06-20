
# definite vs variable binding

`def` binds a name to a value and the binding is not modifiable, meanwhile `var` binds a name to a value and is modifiable.

```luv
typ Box nom {
    thing int
}

fun main() {
    var mutBoxVar = Box.(10)
    mutBoxVar.thing = 20
    mutBoxVar = Box.(10)

    def mutBoxDef = Box.(10)
    mutBoxDef.thing = 20
    # mutBoxDef = Box.(10)      Error!

    var viewBoxVar& = Box.(10)
    # viewBoxVar.thing = 20     Error!
    viewBoxVar = Box.(10)

    def viewBoxDef& = Box.(10)
    # Box.viewBoxDef.thing = 20 Error!
    # Box.viewBoxDef = Box.(10) Error!
}
```

object attributes are variable by default, use `def` before the attribute name to make it definite.

```luv
typ Box nom {
    money int 
}

typ Safe fit {
    def password int
    def box      Box
}

fun main() {
    var s Safe = {
        def password = 1234
        def box = Box.(10)
        # needs the def keyword here
    }

    # s.password = 4321 Error!
    # s.box = Box.(10)  Error!

    s.box.money -= 5 
    # Ok, because box is not a view and money is not definite

    s = {
        def password = 6767
        def box = Box.(6767)
    } # Ok because s is var binded
}
```
