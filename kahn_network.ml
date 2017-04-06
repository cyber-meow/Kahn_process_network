
open Kahn
open Unix




(*let mm = Mutex.create ()

let debug str = 
  Mutex.lock mm;
  Format.printf "%d: %s@." (Thread.id (Thread.self ())) str;
  Mutex.unlock mm *)



let debug str = ()

module Prot = struct

  type sock_kind = SEND | RECEIVE
  type sock = in_channel * out_channel
  type waiting = 
    { send_q : sock Queue.t ; recv_q : sock Queue.t ; m : Mutex.t }

  type get_msg = Get | GetEnd
  type 'a put_msg = Msg of 'a | PutEnd

  let create_waiting () =
    { send_q = Queue.create () ; recv_q = Queue.create () ; 
      m = Mutex.create () }

  let accept_sock s =
    let s_cl, _ = Unix.accept s in
    in_channel_of_descr s_cl, out_channel_of_descr s_cl

  let easy_connect hostname port_num =
    let s = Unix.socket PF_INET SOCK_STREAM 0 in
    try
      let host = Unix.gethostbyname hostname in
      let ip_addr = host.h_addr_list.(0) in
      let addr = ADDR_INET (ip_addr, port_num) in
      connect s addr;
      debug "connect to somebody";
      let in_ch = in_channel_of_descr s in
      let out_ch = out_channel_of_descr s in
      in_ch, out_ch
    with Not_found ->
        Format.printf 
          "cannot connect to the port %d of computer %s@." port_num hostname; 
        exit 1

  let rec accept_adhoc ad s waiting =
    let corres, oth = match ad with
      | SEND -> waiting.send_q, waiting.recv_q
      | RECEIVE -> waiting.recv_q, waiting.send_q 
    in
    if not (Queue.is_empty corres) then Queue.pop corres
    else
      let in_ch, out_ch = accept_sock s in
      debug "to see SEND or RECEIVE";
      if (Marshal.from_channel in_ch : sock_kind) = ad then in_ch, out_ch
      else begin
        Queue.push (in_ch, out_ch) oth;
        accept_adhoc ad s waiting end

  let rec commu_with_send s in_cl out_ser waiting =
    debug "commu_with_send"; 
    let msg : 'a put_msg = Marshal.from_channel in_cl in
    match msg with
    | PutEnd ->
        shutdown (descr_of_in_channel in_cl) SHUTDOWN_ALL;
        close_in in_cl;
        Mutex.lock waiting.m;
        let in_cl, _ = accept_adhoc SEND s waiting in
        Mutex.unlock waiting.m;
        commu_with_send s in_cl out_ser waiting
    | Msg obj ->
        Marshal.to_channel out_ser obj [Marshal.Closures];
        flush out_ser;
        commu_with_send s in_cl out_ser waiting

  let rec commu_with_recv s in_cl out_cl in_ser waiting =
    debug "commu_with_recv"; 
    match (Marshal.from_channel in_cl : get_msg) with
    | GetEnd ->
        shutdown (descr_of_in_channel in_cl) SHUTDOWN_ALL;
        close_out out_cl;
        Mutex.lock waiting.m;
        let in_cl, out_cl = accept_adhoc RECEIVE s waiting in
        Mutex.unlock waiting.m;
        commu_with_recv s in_cl out_cl in_ser waiting
    | Get ->
        let obj = Marshal.from_channel in_ser in
        Marshal.to_channel out_cl obj [Marshal.Closures];
        flush out_cl;
        commu_with_recv s in_cl out_cl in_ser waiting

end



module Net: S = struct

  open Prot

  type channel = 
    { port_num : int ; host : string ; 
      mutable sock : (sock * sock_kind) option ; }

  module CSet = 
    Set.Make(struct type t = channel let compare = compare end)
  
  type 'a process =  CSet.t -> 'a * CSet.t
  type 'a in_port = channel
  type 'a out_port = channel

  let computer_queue = Queue.create ()
  let doco_mutex = Mutex.create ()
  let hostname = Unix.gethostname ()
  let init_port = 2000
  let curr_port = ref init_port


  let new_channel () = 
    debug "new_channel"; 

    let ip_addr = Unix.inet_addr_any in
    incr curr_port;
    let addr = ADDR_INET (ip_addr, !curr_port) in
    let s = Unix.socket PF_INET SOCK_STREAM 0 in
    Unix.setsockopt s SO_REUSEADDR true;
    Unix.bind s addr;
    Unix.listen s 20;
    
    let waiting = create_waiting () in
    let in_ser, out_ser = Unix.pipe () in
    ignore ( 
      Thread.create (fun () -> Unix.handle_unix_error (fun () ->
        debug "send thread";
        Mutex.lock waiting.m;
        let in_send_cl, _ = accept_adhoc SEND s waiting in
        Mutex.unlock waiting.m;
        commu_with_send
        s in_send_cl (out_channel_of_descr out_ser) waiting) ()) (),
      Thread.create (fun () -> Unix.handle_unix_error (fun () ->
        debug "recv thread";
        Mutex.lock waiting.m;
        let in_recv_cl, out_recv_cl = accept_adhoc RECEIVE s waiting in
        Mutex.unlock waiting.m;
        commu_with_recv 
        s in_recv_cl out_recv_cl (in_channel_of_descr in_ser) waiting) ()) ());
    
    (* On fait attention au fait que ch1 et ch2 sont différents! *)
    let ch1 = { port_num = !curr_port ; host = hostname ; sock = None } in
    let ch2 = { port_num = !curr_port ; host = hostname ; sock = None } in
    debug "leave_new_channel"; 
    ch1, ch2


  let put v c opened_ports = 
    debug "put_something"; 
    let out_ch = match c.sock with
      | None -> 
          debug "put_something_none"; 
          let in_ch, out_ch = easy_connect c.host c.port_num in
          c.sock <- Some ((in_ch, out_ch), SEND);
          debug "put_befor_marshal"; 
          Marshal.to_channel out_ch SEND [];
          debug "put_after_marshal"; 
          flush out_ch;
          debug "put_something_succeed"; out_ch
      | Some ((_, out_ch), k) -> assert (k = SEND); out_ch
    in
    Marshal.to_channel out_ch (Msg v) [Marshal.Closures];
    flush out_ch;
    () , CSet.add c opened_ports

  let get (c:'a in_port) opened_ports =
    debug "get_from_channel";
    let in_ch, out_ch = match c.sock with
      | None -> 
          debug "get_from_channel_none";
          let in_ch, out_ch = easy_connect c.host c.port_num in
          c.sock <- Some ((in_ch, out_ch), RECEIVE);
          Marshal.to_channel out_ch RECEIVE []; 
          flush out_ch; in_ch, out_ch
      | Some (chs, k) -> assert (k = RECEIVE); chs
    in
    Marshal.to_channel out_ch Get [];
    flush out_ch;
    (Marshal.from_channel in_ch : 'a), CSet.add c opened_ports


  let close_port port = match port.sock with
    | None -> ()
    | Some ((in_ch, out_ch), sock_kind) ->
        debug "try to close a port";
        begin match sock_kind with
          | SEND -> Marshal.to_channel out_ch PutEnd []
          | RECEIVE -> Marshal.to_channel out_ch GetEnd [] end;
        flush out_ch; close_out out_ch;
        port.sock <- None
  
  (* penser à utiliser mutex pour cette fonction *)
  let send_processes = 
    List.fold_left 
      (fun in_lis proc -> 
        let exec_comp = Queue.pop computer_queue in
        debug @@ "before_connect " ^ exec_comp;
        let in_ch, out_ch = easy_connect exec_comp init_port in
        debug "after_connect";
        Marshal.to_channel out_ch (Msg proc) [Marshal.Closures];
        flush out_ch;
        Queue.push exec_comp computer_queue; in_ch :: in_lis) []

  let doco l opened_ports =
    debug "doco";
    CSet.iter close_port opened_ports;
    debug "finish_close_ports";
    Mutex.lock doco_mutex;
    let in_lis = send_processes l in
    Mutex.unlock doco_mutex;
    debug "finish_send_procs";
    List.iter 
      (fun ch -> 
        debug "must wait finish";
        ignore (input_char ch); 
        shutdown (descr_of_in_channel ch) SHUTDOWN_ALL; close_in ch) in_lis;
    (), CSet.empty

    
  let return v opened_ports =
    debug "return"; v, opened_ports

  let bind p f opened_ports =  
    debug "bind"; 
    let exec, opened_ports' = p opened_ports in
    f exec opened_ports'


  let wait = ref false
  let usage = "usage: <program> [option]"
  let options = 
    [ "-wait", Arg.Set wait, 
      "must be used by all the computers except the principal one" ]
  
  let config_file = ref "network.config"


  let run_proc_thread ((proc : unit process), out_ch) =
    debug "try to run a proc";
    let (), opened_ports = proc CSet.empty in
    debug "this process end";
    debug @@ (string_of_int @@ CSet.cardinal opened_ports) ^ " port(s)";
    CSet.iter close_port opened_ports;
    debug "and close ports";
    output_string out_ch "END";
    flush out_ch; close_out out_ch;
    Thread.exit ()

  let listen_thread () =
    let ip_addr = Unix.inet_addr_any in
    let addr = ADDR_INET (ip_addr, init_port) in
    let s = Unix.socket PF_INET SOCK_STREAM 0 in
    Unix.setsockopt s SO_REUSEADDR true;
    Unix.bind s addr;
    Unix.listen s 20;
    let rec accept_proc () =
      debug "new accept";
      let in_ch, out_ch = accept_sock s in
      debug "accept something";
      match (Marshal.from_channel in_ch : 'a put_msg) with
      | PutEnd -> exit 0  (* on termine le programme, pas que le thread *)
      | Msg (proc : unit process) -> 
          debug "get process";
          ignore (Thread.create (fun () -> 
            Unix.handle_unix_error run_proc_thread (proc, out_ch)) ());
          accept_proc ()
    in
    accept_proc ()


  let run e =

    Arg.parse options (fun str -> config_file := str) usage;
    let conf = open_in !config_file in
    let rec add_computer in_ch =
      try
        let compu = input_line in_ch in
        debug compu;
        Queue.push compu computer_queue; add_computer in_ch
      with End_of_file -> ()
    in
    add_computer conf;

    if !wait then handle_unix_error listen_thread () 
    
    else
      ignore (Thread.create (fun () -> handle_unix_error listen_thread ()) ());
      debug "before exe";
      let res, opened_ports = e CSet.empty in
      CSet.iter close_port opened_ports;
      Queue.iter
        (fun computer -> 
          if computer <> hostname then
          let _, out_ch = easy_connect computer init_port in
          Marshal.to_channel out_ch PutEnd [];
          flush out_ch; close_out out_ch) computer_queue;
      res

end
