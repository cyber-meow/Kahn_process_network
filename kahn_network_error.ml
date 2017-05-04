
let error_mutex = Mutex.create ()

type error_kind =
  | Config_wrong_format of int
  | Main_listen of int * string
  | Listen_invalid
  | Listen_accept_fail of string
  | Channel_no_identification
  | Channel_in_invalid
  | Channel_request_invalid
  | Channel_out_reset
  | Put_channel_no_connect of string * int * string
  | Get_channel_no_connect of string * int * string
  | Get_channel_invalid of string * int
  | Proc_dist_no_host of string
  | Proc_dist_no_connect of string * int * string
  | Wait_finish of string 
  | Doco_peer_reset of string
  | No_computer
  | Close_port_err of string
  | Terminate_program of string * int * string


let print_error_aux = function

  | Config_wrong_format l ->
      Format.eprintf "Warning: @[%s %d %s@]@."
      "The line" l "of the configuration file has the wrong format, ignored."

  | Main_listen (port, err_msg) ->
      Format.eprintf "Error: @[%s %d (%s)@\n%s@]@."
      "The main program cannot listen on port" port err_msg
      "Program exited with code 1."

  | Listen_invalid ->
      Format.eprintf "Warning: @[%s %s@]@."
      "The message that is received by the main listening process is invalid,"
      "ignored."

  | Listen_accept_fail (err_msg) ->
      Format.eprintf "Warning: @[%s@ %s (%s)@\n%s@]@."
      "Problem occurs while the main listening process is trying to accept"
      "connection." err_msg
      "Retry ..."

  | Channel_no_identification ->
      Format.eprintf "Warning: @[%s@]@."
      "The channel cannot identify the type of connection, connectin ignored."

  | Channel_in_invalid ->
      Format.eprintf "Warning: @[%s@ %s@\n%s@]@."
      "The input value of the channel is invalid, the input endpoint might"
      "have been disconnected."  
      "Waiting for another connection ..."

  | Channel_request_invalid ->
      Format.eprintf "Warning: @[%s@ %s@\n%s@]@."
      "The get request received by the channel is invalid, the output endpoint"
      "might have been disconnected."
      "Waiting for another connection ..."

  | Channel_out_reset ->
      Format.eprintf "Warning: @[%s@ %s@\n%s@]@."
      "The channel cannot contact its output endpoint, it might have"
      "been disconnected." 
      "Waiting for another connection ..."
  
  | Put_channel_no_connect (hostname, port, err_msg) ->
      Format.eprintf "Error: @[%s@ %d@ %s@ %s), %s@ (%s)@\n%s@]@."
      "Process cannot connect to the output channel (port" port "of computer" 
      hostname "it might have been shut down." err_msg
      "Process exiting ..."

  | Get_channel_no_connect (hostname, port, err_msg) ->
      Format.eprintf "Error: @[%s@ %d@ %s@ %s), %s@ (%s)@\n%s@]@."
      "Process cannot connect to the input channel (port" port "of computer" 
      hostname "it might have been shut down." err_msg
      "Process exiting ..."

  | Get_channel_invalid (hostname, port) ->
      Format.eprintf "Error: @[%s@ %d@ %s@ %s) %s@\n%s@]@."
      "The value received from the input channel (port" port "of computer"
      hostname "is invalid, the channel might have been closed."
      "Process exiting ..."
  
  | Proc_dist_no_host hostname -> 
      Format.eprintf "Warning: @[%s@ %s@ %s@ %s@ %s@]@."
      "The host of name" hostname "cannot be found, please check your" 
      "settings," "peer ignored."

  | Proc_dist_no_connect (hostname, port, err_msg) -> 
      Format.eprintf "Warning: @[%s@ %d@ %s@ %s@ %s@ %s@ %s@ %s (%s)@\n%s@]@."
      "Cannot connect to port" port "of computer" hostname "while"
      "distributing processes.  There may be problem of configuraton or the"
      "peer might have been shut down.  The node is elimated from the "
      "distribution list." err_msg
      "Continue to distribute processes ..."

  | Wait_finish err_msg ->
      Format.eprintf "Warning: %s@ (%s)@."
      "System error while waiting processes to finish, ignored." err_msg

  | Doco_peer_reset hostname -> 
      Format.eprintf "Warning: @[%s@ %s@ %s@ %s@\n%s@ %s@]@."
      "The connection is reset by peer" hostname "during the excution of" 
      "the process."
      "Redestribution of the process ... (same computations may be repeated"
      "if the process is a source in the model)"

  | No_computer ->
      Format.eprintf "Error: @[%s@\n%s@]@."
      "Cannot connect to any computer of the network (self included)."
      "Program exited with code 2."

  | Close_port_err err_msg ->
      Format.eprintf "Warning: @[%s@ %s@ (%s)@]@."
      "Cannot connect to the channel while trying to close the connection,"
      "ignored." err_msg

  | Terminate_program (hostname, port, err_msg) ->
      Format.eprintf "Warning: @[%s@ %d@ %s@ %s@ %s@ %s@ (%s)@]@."
      "Cannot connect to port" port "of computer" hostname "while trying"
      "to terminate the program, ignored." err_msg

let print_error err =
  Mutex.lock error_mutex;
  Format.eprintf "Thread %d@." @@ Thread.id @@ Thread.self ();
  print_error_aux err;
  Mutex.unlock error_mutex
