
# Test

`test` blocks are never compiled when a program is run. Theres a `fun` test and a `def` test.
`fun` test are functions thats always module scoped, only compiled when tests are run.
`def` test defines the testcases, and can call `fun` test.


```luv
typ Box nom[T any] {
    item T
}

fun Box.unpack[T any](own Box[T]) T {
    return own.item
} 

fun test makeBox() Box[int] {
    return Box.(10)
}

fun test makeBoxStr() Box[str] {
    return Box.("str")
}

def test "TestBox" {
    var b = makeBox()
    var unpacked = b.unpack()
    if unpacked != 10 {
        return Err.("Error")
    }
}

def test "TestBoxStr" {
    var b = makeBoxStr()
    var unpacked = b.unpack()
    if unpacked != "str" {
        return Err.("Error")
    }
}
```

`def` test block returns a type of nil!any, any error values raised will be inspected in the CLI.

