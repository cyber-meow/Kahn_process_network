# Kahn_process_network
A library containing diffierent implementations of KPN in OCaml and example uses of this library.  Class project for the system and network course at ENS.

## Structure
In the file __Kahn.ml__ is defined the monadic interface of the KPN model (__Kahn.S__); this file contains also a module Lib that is quite useful in practice (notably the symbol `>>=` for bind).  The root of the directory contains in addition the five different implementaions of the interface (seq, lwt, th, proc, network) and finally in the file _impls.ml_ we find _KPN_prog_ which is suitable to express most of the programs that are written using this library and the functor _Choose_impl_ which allows us to run a such program with different implementations.  This is mainly for a test purpose.  When a program is wrapped with this functor, we use the specification `-impl seq | lwt | th | proc | net` to choose the implementation to use (`seq` by default).

## Implementations
 
