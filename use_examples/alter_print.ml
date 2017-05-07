
(**************************************************************************)
(*                                                                        *)
(* Another trivial example for the use of the KPN library                 *)
(*                                                                        *)
(* It's however in fact mainly used to illustrate a bug of the network    *)
(* implementation. Two processes take turns reading and writing in a pair *)
(* of channels, but if one process is stopped by accident, this process   *)
(* is redistributed and needs to be run from the beginning. This can lead *)
(* to blockage due to a bad order of put and get.                         *)
(*                                                                        *)
(**************************************************************************)

module Alter_print (K : Kahn.S) = struct

  module K = K
  module Lib = Kahn.Lib(K)
  open Lib

  let rec receive_put qi qo =
    K.get qi >>=
    fun n -> Format.printf "%d@." n; K.put (n+1) qo >>=
    fun () -> receive_put qi qo

  let main = 
    delay K.new_channel () >>=
    fun (q_in1, q_out1) -> K.return (K.new_channel ()) >>=
    fun (q_in2, q_out2) ->
      K.doco [ receive_put q_in1 q_out2;
               K.put 0 q_out1 >>= fun () -> receive_put q_in2 q_out1 ]

end

module Alter_pr = Impls.Choose_impl(Alter_print)
let () = Alter_pr.run ()
