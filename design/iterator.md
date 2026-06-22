
# Iterator

Iterators are a language feature that is used for a range based `for` loop.

It's definition is roughly like this:

```luv
typ Iter fit[T any] {
    next(Own) T?
}

typ Iterable fit[T any] {
    toIter(Own) Iter[T]
}
```

Every values in the `for in` loop will be automatically unwrapped. 
If yields nil, it will stop the execution of the `for` loop.

`for in` loop only accepts `Iter` or `Iterable`.
