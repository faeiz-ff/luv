
# tag Type

The `tag` type is a tagged union. It can represent multiple types in one, but only one type is valid at a time.
The `tag` value then must be `match`-ed for what it represent. To match a `tag` in a `match` expression,
use the name of the tagname, if capturing is needed, precede the tagname by an identifier.

```luv
typ Shape tag {
    Circle    flo
    Square    flo
    Rectangle [ flo, flo ]
    Dot       nil
}

fun Shape.getArea(own Shape) flo {
    return match own {
        radius of Circle -> radius * radius * Math.pi
        length of Square -> length * length
        height, width of Rectangle -> height * width
        Dot -> 0
    }
}

fun main() {
    var shape Shape = Shape.Circle.(10)
    var area = shape.getArea()
}
```

`else` can be used inside a `match-tag` expression for a catchall. But the captured variable will be of type `any`.

tag variants can be created using the dotPostFix of objLiteral or tupLiteral. With objLiteral creation, an object will be created, this only works for fit. with tupLiteral of one element, it will assign it as the value. With tupLiteral of two or more, the args will be of N element tuple. If nil or [] is the variant type, then the 0 argument tuple will construct that.

## Builtin Tag

Theres a builtin `tag` of Option and Result which has builtin functionalities and operators.

### Option

Options are well, optional values. It represent either something or nothing. 
Option is generic, its definition is roughly like this.

```luv
typ Option tag[T any] {
    Some T
    None nil
} # wow very original
```

But we don't need to actually type `Option[T]`, theres a `?` shorthand at the type level: `T?`, and at the variable declaration level: `var a? = 10` to automatically infer the expression type and put an Option on it.

### Result

Result represent a type that may fail. It represent an Ok tag or Err tag. It is generic for both tag.

```luv
typ Result tag[T any, U any] {
    Ok  T 
    Err U
}
```

A shorthand for Result type is `T!U` where T is the Ok and U is the Err.

## Builtin Tag Operators

### PostFix ? Operator

A `?` operator returns an Option / Result at the variable level, but can be chain operated into the 'ok' type in the expression level.

If operated on Option, the resulting type will be the optional of the last expression type.
This allows multiple chaining of `?` operator on Option freely as the None type will always be nil.

```luv
fun main() {
    var thing fit {
        num int?
        dec flo?
    }? = nil

    var num int? = thing?.num 
    var sum flo? = thing?.num? + thing?.dec? 

    # var illegal = thing?.num + thing?.dec?
    #                        ^ this is of type int? cant be operated for '+'
}
```

If operated on Result, the resulting type will be the Result with the last expression type as OK, and the type of the first occurence of `?` as Err.
This disallows multiple chaining of `?` operator on Result if the Err type is mismatched accross the chain.

```luv
typ Inner fit {
    num int
}

typ Data fit {
    something Inner!str
}

fun mayFail() Data!str {
    return Ok.{ something = Ok.{ num = 1 } }
}

fun willFail() Data!int {
    return Err(10)
}

fun main() {
    var valid = mayFail()?.something      # Inner!str
    var valid = mayFail()?.something?.num # int!str
    
    # var illegal = willFail?.something 
    #                                 ^ expect str as Err, found int
}
```

### PostFix ! Operator

Result and Option may use the `!` operator to return the 'fail' type at function level, analogous to 'try' in zig.
The function return type must return optional type for Optional, or return a matching Err type for Result. 

```luv
fun mayFailOption(num int?) int? {
    return num! + 1
}

fun mayFailResult(num int!sym{Nil}) int!sym{Nil} {
    return num! + 1
}
```
