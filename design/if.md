
# If expression

If expression is the usual conditional block in many other languages.
It can be used as a statement or an expession.

It can use a shorthand `->` to yield an expression.

As an expression, the yielded result must be of the same type.

```luv

var thing = if true -> 1 else -> 10

var cond = true
var num = 1

if cond && num == 0 {
    print("no")
} elif cond && num == 1 {
    print("yes")
} else {
    print("no")
}

```

If also may define a variable inside the condition. The variable is valid inside the condition and the `then` block if the condition pass.

The expression that is in the variable must be a PostFix expression, if a general expression is needed, it needs to be parenthesized

```luv

if var a = 10 and a == 10 {
    # a is valid here
} elif var b flo = 3 and b > 2  {
    # b is valid here
}
```

The guard may also match a tag to narrow the type, this `var` type narrowing is only possible in ifGuard.

```luv
var a int? = 10

if var b Some = a and b < 11 {
    print("yes")
}
```

