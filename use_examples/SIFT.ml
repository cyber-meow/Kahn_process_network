
(**************************************************************************)
(*                                                                        *)
(* Distributed sieve of Erastothenes algorithm KPN implementation         *)
(*                                                                        *)
(* Reference:                                                             *)
(*  Gilles Kahn and David Macqueen,                                       *)
(*  Coroutines and networks of parallel processes                         *)
(*                                                                        *)
(**************************************************************************)

module SIFT (K : Kahn.S) = struct

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
  
  let filter prime qi qo =
    let rec loop () =
      K.get qi >>= 
      fun n -> (if (n mod prime) != 0 then K.put n qo else K.return ()) >>=
      fun () -> loop ()
    in
    loop ()

  let rec sift qi qo =
    K.get qi >>= fun prime -> K.put prime qo >>=
    fun () -> K.return (K.new_channel ()) >>=
    fun (q_in, q_out) -> K.doco [ filter prime qi q_out ; sift q_in qo ]

  let main =
    delay K.new_channel () >>= 
    fun (q_in1, q_out1) -> K.return (K.new_channel ()) >>=
    fun (q_in2, q_out2) ->
      K.doco [ integers 2 q_out1 ; sift q_in1 q_out2 ; output q_in2 ]

end

module SI = Impls.Choose_impl(SIFT)
let () = SI.run ()
