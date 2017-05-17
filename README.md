# Kahn_process_network
A library containing diffierent implementations of KPN in OCaml and example uses of this library.  Class project for the system and network course at ENS.

## Usage 

### Requirements
- OCaml >= 4.03.0 (for the network implementaion, problem of marshalling)
- The library `Lwt`

### Interface
In the file __kahn.ml__ is defined the monadic interface of the KPN model (`Kahn.S`).
```OCaml
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
The file __kahn.ml__ contains also a module `Lib` that is quite useful in practice (notably the symbol `>>=` for `bind`).  

Otherwise, in the file __impls.ml__ there is `KPN_prog` which is suitable to express most of the programs that are written using this library and the functor `Choose_impl` that allows us to run a such program with different implementations.  This is mainly for a test purpose.  When a program is wrapped with this functor, we use the specification `-impl seq | lwt | th | proc | net` to choose the implementation to use (`seq` by default).  You can refer to the files in the directory __use_examples/__ for concrete examples.

## Implementations
The five different implementaions of the interface (seq, lwt, th, proc, network) are found in the root of the directory.

### Sequential implementation: kahn_seq.ml
We try to simulate the parallelism in a single thread.  For more details please refer to [A Poor Man's Concurrency Monad](http://www.seas.upenn.edu/~cis552/11fa/lectures/concurrency.html).  We're just rewriting the code of Haskell in OCaml in a framewrok that is appropriate for our KPN interface (so with `doco`).  In particular the continuation-passing style is adopted.

### With the `Lwt` library: kahn_lwt.ml
This is simply a translation from the OCaml cooperative threads library [Lwt](http://ocsigen.org/lwt/) in our interface.  Since the library itself is much more complex, it serves mainly as a reference.  I sincerly recommend those who're interested in multi-thread programming in OCaml to take a look a this library (and anyway if you use [Ocsigen](http://ocsigen.org/) you surely already know it).

### The library `Thread`: kahn_th.ml
Yet another possiblilty is to use the standard lightweight preemptive threads library [Thread](https://caml.inria.fr/pub/docs/manual-ocaml/libref/Thread.html) of OCaml.  In fact this implementation is offered directly by the professor.  One should notice that real parallelism cannot be perfectly reached in OCaml at this moment due to the problem related to its _ramasse-miettes_.

### Mutli-processe implementation: kahn_proc.ml
Processes in the model are simulated directely by computer processes (i.e. `Unix.fork`) who communicates with each other using pipes.  This implementation may be considered particularly for multi-core computers.

### Network: kahn_network.ml & kahn_network_error.ml
This is the network version where communications between different computers are done via sockets.  This is the most sophisticated version and for a detailed explication please see our report (it's however in French).  In general, this implementation only works for OCaml >= 4.03.0 (tested with versions 4.03.0 and 4.04.0), but in some very basic cases, it may work for OCaml <= 4.02.0, which is the case for the two files __int_printer_network.ml__ and __sieve_Erastosthenes.ml__ in __use_examples/__.

#### How to use
There are three different command line options:
- `-wait`
- `-port`
- `-config`

The option `-wait` must be used on all the computers except the principal one which should be executed at the end to start the program.  The option `-port` is then used to specify the main listening port (default 1024).

To launch a program that uses this implementation, one should include a file named __network.config__ (the name of the file can also be specified by the option `-config`) in the directory where the program is runned.  This file consists of the information of peers that form the network (i.e names of computers and possibly their respective listening ports, by default the port 1024).  The file needs to be of the following format.
```
Computer1 [port1]
Computer2 [port2]
...
```
The same computer can appear several times as long as the listening ports are different (but contiguous port numbers should be avoided due to a bug of the implementation).  This may be useful if we want to execute the program on different cores of the computer since with only one instance of the program this cannot be reached because here we use the library `Thread` instead of doing directly a `Unix.fork`.  Below is a legal example of the file __network.config__.
```
tamier 2000
trolle
trolle 12345
tulipier
```
Notice that when a peer is shut down during the execution, the whole program may or may not continue to work corretly since all the KPN processes that are stopped abnormally will simply be restarted from the beginning. 

#### Related to the command line parsing
I spent some time trying to find a way that allows us to do the command line parsing in different places of the OCaml code, but I was not able to find a perfect way to solve the problem.  So after the command line parsing of the network implementation (and the same for the functor `Choose_impl`), there may be empty strings as command line arguments.  The main program must ignore them .  One can also consider to include the specifications of different options listed above in their error message.

## Examples
In the directory __use_examples/__ you can find codes that are written using this library.  Please refer to individual file for a detailed explication of the command line options that are available for each program.

### Basic examples
- __put_get_test.ml__: One process puts a 2 in a channel and another process reads and prints it out.  Run `make put_get` to generate this program.
- __int_printer.ml__: One process puts integers in a channel in an infinite loop while the other process reads from this channel and prints out these values.  Run `make int_printer` to generate the program.
- __alter_print.ml__: Two processes alternately read and write in a pair of channels. Run `make alter_print` for this program.

### Sieve of Eratosthenes
We implement the algorithm described on the page 9. of the article [Coroutines and Networks of Parallel Processes.](https://hal.inria.fr/inria-00306565/PDF/rr_iria202.pdf) of Gilles Kahn and David Macqueen.  The number of KPN processes that are used in this algorithm is unbounded, thus it doesn't work very well with the network implementation.  Run `make prime_sieve` to generate the program.

### Mandelbrot set
> The Mandelbrot set is the set of complex numbers c for which the function f<sub>c</sub>(z)=z<sup>2</sup>+c does not diverge when iterated from z=0, i.e., for which the sequence f<sub>c</sub>(0), f<sub>c</sub>(f<sub>c</sub>(0)), etc., remains bounded in absolute value.
> 
> _-Wikipedia_

Plot the Mandelbrot set for the range [-2, 2] &times; [-1.5, 1.5].  The image is divided into several zones and the computation of each zone is carried out by an individual process.  You can specify the size of the image, the number of zones, the number of iterations to run for each single point etc.   Run `make mandelbrot` to generate the program.

![Mandelbrot set](http://i.imgur.com/dJiADgf.jpg)

### Pong
This is a pong game that is played on two computers.  Therefore it uses only the network version of the library.  On one computer the program is started with the option `-wait` and on the other computer you can specify the game parameters.  Run `make pong` to generate this program.

### k-means
The parallel k-means clustering algorithm.  The input file should contain on each line a point whose coodinates are separated by spaces.  The number of clusters `k`, the number of iterations `i`, the number of workers `p`, and the number of times to run the algorithm `t` (again it will be in parallel) can be given as arguments.  The cluster centers are then computed and printed in an output file whose name can be specified by the option `-o`.  When input points are of dimension 2, the option `-plot` can be given to plot the result, then you may want to use `-w` and `-h` to specify the width and the height (in pixels) of the display window.  To generate this program, run `make k_means`.
