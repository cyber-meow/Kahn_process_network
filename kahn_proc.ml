
open Kahn
open Unix

module Proc: S = struct

    type 'a process = (unit -> 'a)

    type 'a channel = { i: in_channel; o: out_channel; m: Mutex.t}
    type 'a in_port = 'a channel
    type 'a out_port = 'a channel

    let new_channel () = 
      let r, w = Unix.pipe () in
      let i, o = Unix.in_channel_of_descr r, Unix.out_channel_of_descr w in
      let c = { i; o; m = Mutex.create () } in 
      c, c

    let put v c () =
      Mutex.lock c.m;
      Marshal.to_channel c.o v [Marshal.Closures];
      flush c.o;
      Mutex.unlock c.m

    let rec get (c:'a in_port) () = 
      try
        Mutex.lock c.m;
        let v = (Marshal.from_channel c.i : 'a) in
        Mutex.unlock c.m; 
        v
      with End_of_file ->
        get c ()

    let rec doco l () = match l with
    | [] -> ()
    | p::ps -> match Unix.fork () with
        | 0 -> p (); exit 0
        | pid -> doco ps (); ignore (Unix.waitpid [] pid)

    let return v = (fun () -> v)
    let bind p f () = f (p ()) ()

    let run e = e ()

end
