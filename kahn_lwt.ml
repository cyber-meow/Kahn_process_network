
open Kahn

module Lwt_th: S = struct

  type 'a process = 'a Lwt.t

  type 'a channel = { s: 'a Lwt_stream.t ; push : 'a option -> unit }
  type 'a in_port = 'a channel
  type 'a out_port = 'a channel

  let new_channel () =
    let s, push = Lwt_stream.create () in
    {s;push}, {s;push}

  let put v c = Lwt.return @@ c.push (Some v)
  let get c = Lwt_stream.next c.s

  let doco = Lwt.join

  let return = Lwt.return
  let bind = Lwt.bind
  
  let run = Lwt_main.run

end

