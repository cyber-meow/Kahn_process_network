
(************************************************************************)
(*                                                                      *)
(* The very basic example that illustrates the use of the KPN library   *)
(*                                                                      *)
(* The producer puts a 2 in a channel;                                  *)
(* the consommator receives it and prints it.                           *)
(*                                                                      *)
(************************************************************************)

module Put_get (K : Kahn.S) = struct

  module K = K
  module Lib = Kahn.Lib(K)
  open Lib

  let main : unit K.process =
    delay K.new_channel () >>= fun (q_in, q_out) -> K.doco 
    [ K.put 2 q_out ; 
      K.get q_in >>= fun v -> K.return (Format.printf "%d@." v) ]

end

module PG = Impls.Choose_impl(Put_get)
let () = PG.run ()
