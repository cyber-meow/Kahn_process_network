
open Kahn
open Unix

module Proc: S = struct

    type 'a process = (unit -> 'a)

    type 'a in_port = in_channel
    type 'a out_port = out_channel

    let new_channel () = 
      let r, w = Unix.pipe () in
      Unix.in_channel_of_descr r, Unix.out_channel_of_descr w

    let put v c () =
      Marshal.to_channel c v [Marshal.Closures]

    let rec get (c:'a in_port) () = 
      try
        (Marshal.from_channel c : 'a)
      with End_of_file ->
        get c ()

    let rec doco l () = match l with
    | [] -> ()
    | p::ps -> match Unix.fork () with
        | 0 -> p (); exit 0
        | _ -> doco ps (); ignore (Unix.wait ())

    let return v = (fun () -> v)
    let bind p f () = f (p ()) ()

    let run e = e ()

end
