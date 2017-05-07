# Kahn_process_network
A library containing diffierent implementations of KPN in OCaml and example uses of this library.  Class project for the system and network course at ENS.

## Structure
In the file __Kahn.ml__ is defined the monadic interface of the KPN model (`Kahn.S`); this file contains also a module `Lib` that is quite useful in practice (notably the symbol `>>=` for `bind`).  In the root of the directory we find equally the five different implementaions of the interface (seq, lwt, th, proc, network) and finally in the file __impls.ml__ there is `KPN_prog` which is suitable to express most of the programs that are written using this library and the functor `Choose_impl` that allows us to run a such program with different implementations.  This is mainly for a test purpose.  When a program is wrapped with this functor, we use the specification `-impl seq | lwt | th | proc | net` to choose the implementation to use (`seq` by default).

## Implementations
### Sequential implementation: kahn_seq.ml
We try to simulate the parallelism in a single thread.  For more details please refer to ![A Poor Man's Concurrency Monad](http://www.seas.upenn.edu/~cis552/11fa/lectures/concurrency.html).  We're just rewriting the code of Haskell in OCaml in a framewrok that is appropriate for our KPN interface (so with `doco`).  In particular the continuation-passing style is adopted.

### With the `Lwt` library: kahn_lwt.ml
This is simply a translation from the OCaml cooperative threads library ![Lwt](http://ocsigen.org/lwt/) in our interface.  Since the library itself is much more complex, it serves mainly as a reference.  I sincerly recommend those who're interested in multi-thread programming in OCaml to take a look a this library (and anyway if you use ![Ocsigen](http://ocsigen.org/) you surely already know it).

### The library `Thread`: kahn_th.ml
Yet another possiblilty is to use the standard lightweight preemptive threads library ![Thread](https://caml.inria.fr/pub/docs/manual-ocaml/libref/Thread.html) of OCaml.  In fact this implementation is offered directly by the professor.  One should notice that real parallelism cannot be perfectly reached in OCaml at this moment due to the problem related to the _ramasse-miettes_.

### Mutli-processe implementation : kahn_proc.ml
