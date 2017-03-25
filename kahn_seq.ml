
open Kahn

module Seq: S = struct

  type action = 
    | Stop
    | Action of (unit -> action)
    | Doco of action list

  type 'a process = ('a -> action) -> action

  type 'a in_port = 'a Queue.t
  type 'a out_port = 'a Queue.t

  let new_channel () =
    let q = Queue.create () in q, q

  let put v out_p (k: unit -> action) =
    Queue.push v out_p; Action k

  let rec get (in_p: 'a in_port) (k: 'a -> action) =
    try
      let v = Queue.pop in_p in
      Action (fun () -> k v)
    with Queue.Empty ->
      Action (fun () -> get in_p k)

  let doco (l: unit process list) (k: unit -> action) =
    let remaining = ref @@ List.length l - 1 in
    let k' () = match !remaining with
    | 0 -> k ()
    | n -> decr remaining; Stop in
    Doco (List.map (fun proc -> proc k') l)

  let return (v:'a) (k: 'a -> action) = Action (fun () -> k v)

  let bind (e: 'a process) (f: 'a -> 'b process) (k: 'b -> action) =
    e (fun a -> f a k)

  let run (e: 'a process) =
    let (res: 'a option ref) = ref None in
    let action = e (fun a -> res := Some a; Stop) in
    let running = Queue.create () in
    Queue.push action running;
    let rec run_aux (q: action Queue.t) =
      if Queue.is_empty q then () 
      else 
        match Queue.pop q with
        | Stop -> run_aux q
        | Action act -> Queue.push (act ()) q; run_aux q
        | Doco al -> List.iter (fun ac -> Queue.push ac q) al; run_aux q
    in
    run_aux running;
    match !res with
    | None -> assert false
    | Some a -> a

end
