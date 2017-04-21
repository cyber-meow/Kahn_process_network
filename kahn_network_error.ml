
type error_kind =
  | Proc_dist_no_host of string
  | Proc_dist_cannot_connect of string * int
  | Proc_dist_peer_reset of string
  | Doco_peer_reset


let print_error = function

  | Proc_dist_no_host hostname -> 
      Format.eprintf "%s%s%s\n%s@."
      "Warning: The host of name " hostname " cannot be found, please check"
      "         your settings, peer ignored ..."

  | Proc_dist_cannot_connect (hostname, port) -> 
      Format.eprintf "%s%d%s%s%s\n%s\n%s\n%s@."
      "Warning: Cannot connect to port " port " of computer " hostname " while"
      "         distributing processes.  There may be problem of configuratons"
      "         or the peer might be shutdown. The node is elimated from the"
      "         distribution list.  Continue to distribute proccesses ..."

  | Proc_dist_peer_reset hostname ->
      Format.eprintf "%s%s%s\n%s@."
      "Warning: The connection is reset by peer " hostname " while"
      "         distributig processes. Try to connect to another peer ..."

  | Doco_peer_reset -> 
      Format.eprintf "%s\n%s\n%s@."
      "Warning: The connection is reset by peer during the excution of the"
      "         process, redestribution of the process ... (same computations"
      "         may be again executed if the process is a source in the model)"

