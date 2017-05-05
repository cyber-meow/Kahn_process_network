
module type KPN_prog =
  functor (Kahn_impl: Kahn.S) ->
    sig 
      val main: unit Kahn_impl.process 
    end

module Choose_impl(Prog: KPN_prog): sig val run: unit -> unit end = struct

  let choose_impl = function
    | "th" -> (module Kahn_th.Th: Kahn.S)
    | "proc" -> (module Kahn_proc.Proc: Kahn.S)
    | "seq" -> (module Kahn_seq.Seq: Kahn.S)
    | "lwt" -> (module Kahn_lwt.Lwt_th: Kahn.S)
    | "net" -> (module Kahn_network.Net: Kahn.S)
    | str -> 
        Format.eprintf "Error: %s %s@ %s@."
        "unknown implementation option" str
        "Possible implementation choices: seq, lwt, th, proc, net"; exit 1
 
  let impl = ref "seq"

  let options =
    ["-impl", Arg.Set_string impl, 
     "choose the KPN implementation to use"] 
  let new_argv = Array.make (Array.length Sys.argv) ""
  let new_argv_ind = ref 0
    
  let update_new_argv str =
    new_argv.(!new_argv_ind) <- str;
    incr new_argv_ind
  
  let current = ref 0
    
  let rec rec_parse () =
    try
      Arg.parse_argv ~current Sys.argv options 
        (fun str -> update_new_argv str) ""
      with Arg.Bad _ | Arg.Help _ ->
        update_new_argv (Sys.argv.(!current)); rec_parse ()

  (* comme Kanh.S.run, cette fonction s'exécute au plus une fois,
     sinon pas de sense *)
  let run () =
    update_new_argv Sys.argv.(0);
    rec_parse ();
    Array.blit new_argv 0 Sys.argv 0 (Array.length Sys.argv);
    let (module Kahn_impl) = choose_impl !impl in
    let module Prog = Prog(Kahn_impl) in
    Kahn_impl.run Prog.main

end
