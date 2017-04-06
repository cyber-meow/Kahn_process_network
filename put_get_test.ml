
module Example (K : Kahn.S) = struct

  module K = K
  module Lib = Kahn.Lib(K)
  open Lib

  let main : unit K.process =
    delay K.new_channel () >>= fun (q_in, q_out) -> K.doco 
    [ K.put 2 q_out ; 
      K.get q_in >>= fun v -> K.return (Format.printf "%d@." v) ]

end

module E = Example(Kahn_network.Net)

let () = E.K.run E.main
