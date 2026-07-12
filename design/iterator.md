
# Iterator

Iterators are a language feature that is used for a range based `for` loop.

It's definition is roughly like this:

```luv
typ Iter[T any] fit {
    next(Own) T?
}

typ Iterable[T any] fit {
    toIter(Own) Iter[T]
}
```

Every values in the `for in` loop will be automatically unwrapped. 
If yields nil, it will stop the execution of the `for` loop.

`for in` loop only accepts `Iter` or `Iterable`.
