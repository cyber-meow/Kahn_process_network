
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
