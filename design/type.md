
# Type System

There are two typing mode in luv, Nominal and Structural. All of the type will be erased at the runtime, and there are no runtime type conversions.

## Nominal Typing

Nominal type represents C-like structs where only the identity of type matters for equivalence, not its shape.

```luv
typ Player nom {
    name str
    health int
}

fun main() {
    var playa = Player("user", 100)

    var entity = { 
        name = "user"
        health = 100
    } # is of type fit { name str, health int }

    playa = entity # not ok
}

```

Nominal type can have namespace with the same name as the type name. The namespace cannot be accessed through instances created by the nominal type.

```luv
def Player.MAX_HP = 100
def Player.DEFAULT_NAME = "Jane Doe"
```

Functions that live inside a nominal type's namespace with the first argument being the type itself will act as a method for that type.

```luv
typ Player nom {
    name str
    hp int
    maxHp int
}

fun Player.getDepletedHp(own Player) str {
    return own.maxHp - own.hp
}

fun main() {
    var playa = Player("user", 60, 100)
    var depleted = playa.getDepletedHp()
    # var depleted = Player.getDepletedHp(playa)
}
```

The methods will be stored in one VTable where each instances will carry the pointer to it.

`nom` and `tag` are Nominally typed.

## Structural Typing 

Structural type represents the opposite of Nominals, they dont care about identity, only shape. Represented by the `fit` keyword.

```luv
typ Vec2 fit {
    x int
    y int
}

typ Pair nom {
    x int 
    y int
}

fun main() {
    var v1 Vec2 = { x = 1, y = 2 }
    var v2 Vec2 = Pair(10, 20) # ok

    var v3 Vec2 = { 
        x = 1 
        y = 2 
        z = 3 
    } 
    # also ok, but z is unreachable
}

```

Because there can be so many shape of an object that fits a `fit`, it cannot have namespace on its own. 
But because nominals may carry a VTable pointer, the object shape in a `fit` may also include the method, creating an interface.

```luv
typ Pair nom {
    x int 
    y int
}

fun Pair.add(own Pair) int {
    return own.x + own.y
}

typ Addable fit {
    add(Own) int
}

fun main() {
    var p = Pair(10, 20)
    var a1 Addable = p 
    # a1 shape is { add(Own) int } and thats it, 
    # x and y still exist but its unreachable by a1

    print(a1.add()) # 30
}
```

`Own` keyword refers to the original type it is capturing, its only valid inside a fit.
The captured type is the fully qualified one, meaning all generic parameters must be fulfilled.

```luv
typ Addable fit {
    add(Own, Own) Own
}

typ Pair nom[T any] {
    first T 
    second T
}

fun Pair.add(own Pair[int]) int {
    return own.first.toInt() + own.second.toInt()
}
```

In the above example, `Addable` is only satisfied by `Pair[int]` and nothing else.

