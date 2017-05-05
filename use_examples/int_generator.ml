
(************************************************************************)
(*                                                                      *)
(* A simple example illustrating the use of the KPN library             *)
(*                                                                      *)
(* The producer puts integers in the channel in a infite loop and the   *)
(* consommator prints out the values received from the channel.         *)
(*                                                                      *)
(************************************************************************)

module Example (K : Kahn.S) = struct

  module K = K
  module Lib = Kahn.Lib(K)
  open Lib

  let integers n0 (qo : int K.out_port) : unit K.process =
    let rec loop n =
      K.put n qo >>= fun () -> loop (n + 1)
    in
    loop n0

  let output (qi : int K.in_port) : unit K.process =
    let rec loop () =
      K.get qi >>= fun v -> Format.printf "%d@." v; loop ()
    in
    loop ()

  let main : unit K.process =
    delay K.new_channel () >>=
    fun (q_in, q_out) -> K.doco [ integers 2 q_out ; output q_in ]

end

module E = Impls.Choose_impl(Example)
let () = E.run ()
