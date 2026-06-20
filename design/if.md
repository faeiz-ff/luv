
# If expression

If expression is the usual conditional block in many other languages.
It can be used as a statement or an expession.

It can use a shorthand `->` to yield an expression.

As an expression, the yielded result must be of the same type.

```luv
fun main() {
    var thing = if true -> 1 else -> 10

    var cond = true
    var num = 1

    if cond and num == 0 {
        print("no")
    } elif cond and num == 1 {
        print("yes")
    } else {
        print("no")
    }
}

```

If also may define a variable inside the condition. The variable is valid inside the condition and the `then` block if the condition pass.

The expression that is in the variable must be a PostFix expression, if a general expression is needed, it needs to be parenthesized

```luv
fun main() {
    if var a = 10 and a == 10 {
        # a is valid here
    } elif var b flo = 3 and b > 2  {
        # b is valid here
    } elif var c = 1 and var d = (c + 1) {
        # c and d is valid here, mind the parentheses on d's expression
    }
}
```

The guard may also match a tag to narrow the type, this `var` tag narrowing is only possible in ifGuard.

```luv
fun main() {
    var a int? = 10

    if var b of Some = a and b < 11 {
        print("yes")
    }
}
```

The guard can be repeated as many times before theres an expression (if any), after that it will continue parsing an expression.
