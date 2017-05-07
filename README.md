# Kahn_process_network
A library containing diffierent implementations of KPN in OCaml and example uses of this library.  Class project for the system and network course at ENS.

## Usage 
### Requirements
- OCaml >= 4.03.0 (for the network implenmentaion, problem of marshalling)
- The library `Lwt`

### Interface
In the file __kahn.ml__ is defined the monadic interface of the KPN model (`Kahn.S`).
```ocaml
module type S = sig
  type 'a process
  type 'a in_port
  type 'a out_port
  
  val new_channel: unit -> 'a in_port * 'a out_port
  val put: 'a -> 'a out_port -> unit process
  val get: 'a in_port -> 'a process
  
  val doco: unit process list -> unit process
  
  val return: 'a -> 'a process
  val bind: 'a process -> ('a -> 'b process) -> 'b process
  val run: 'a process -> 'a
end
```

- The type `'a process` represents a computation that may take time and returns a result of type `'a`
- The types `'a in_port` and `'a out_port` represent respectively the part of a channel that we can read and write
- The function `new_channel` creates a new channel; the functions `put` and `get` allows respectively to put a value to a channel and to read a value from the channel
- The function doco executes a list of processes in parallel and wait for all the processes to finish before continuing
- The function `return` creates a process that terminates immediately by returng its argument
- The function `bind` creates a process that runs its fisrt argument process and than executes its second argument by giving it the value that has just been returned 
- The function `run` executes a process and returns the result value (in a well-formed model, this function should only be called one time -- at the end of the program)

### For your convenience
The file __kahn.ml__ contains also a module `Lib` that is quite useful in practice (notably the symbol `>>=` for `bind`).  Otherwise, in the file __impls.ml__ there is `KPN_prog` which is suitable to express most of the programs that are written using this library and the functor `Choose_impl` that allows us to run a such program with different implementations.  This is mainly for a test purpose.  When a program is wrapped with this functor, we use the specification `-impl seq | lwt | th | proc | net` to choose the implementation to use (`seq` by default).  You can refer to the files in the directory __use_examples__ for concrete examples.

## Implementations
The five different implementaions of the interface (seq, lwt, th, proc, network) are found in the root of the directory.
### Sequential implementation: kahn_seq.ml
We try to simulate the parallelism in a single thread.  For more details please refer to ![A Poor Man's Concurrency Monad](http://www.seas.upenn.edu/~cis552/11fa/lectures/concurrency.html).  We're just rewriting the code of Haskell in OCaml in a framewrok that is appropriate for our KPN interface (so with `doco`).  In particular the continuation-passing style is adopted.

### With the `Lwt` library: kahn_lwt.ml
This is simply a translation from the OCaml cooperative threads library ![Lwt](http://ocsigen.org/lwt/) in our interface.  Since the library itself is much more complex, it serves mainly as a reference.  I sincerly recommend those who're interested in multi-thread programming in OCaml to take a look a this library (and anyway if you use ![Ocsigen](http://ocsigen.org/) you surely already know it).

### The library `Thread`: kahn_th.ml
Yet another possiblilty is to use the standard lightweight preemptive threads library ![Thread](https://caml.inria.fr/pub/docs/manual-ocaml/libref/Thread.html) of OCaml.  In fact this implementation is offered directly by the professor.  One should notice that real parallelism cannot be perfectly reached in OCaml at this moment due to the problem related to its _ramasse-miettes_.

### Mutli-processe implementation : kahn_proc.ml
Processes in the model are simulated directely by computer processes (i.e. `Unix.fork`) who communicates with each other using pipes.  This implementation may be considered particularly for multi-core computers.

### Network
