
open Kahn
open Unix

open Kahn_network_error


let debug str = ()


let mm = Mutex.create ()

let debug str = 
  Mutex.lock mm;
  Format.printf "%d: %s@." (Thread.id (Thread.self ())) str;
  Mutex.unlock mm


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

  (* Exceptions that need to be handled: 
     Unix_error (EADDRINUSE, _, _), Unix_error (EADDRNOTAVAIL, _, _) *)
  let listen_port port_num =
    debug @@ "listen at port " ^ (string_of_int port_num); 
    let ip_addr = Unix.inet_addr_any in
    let addr = ADDR_INET (ip_addr, port_num) in
    let s = Unix.socket PF_INET SOCK_STREAM 0 in
    Unix.setsockopt s SO_REUSEADDR true;
    Unix.bind s addr;
    Unix.listen s 20; s

  let accept_sock s =
    let s_cl, _ = Unix.accept s in
    in_channel_of_descr s_cl, out_channel_of_descr s_cl

  (* Exceptions that need to be handled: 
     Not_found, 
     Unix_error (ECONNREFUSED, _, _), Unix_error (ETIMEOUT, _, _), ... *)
  let easy_connect hostname port_num =
    let s = Unix.socket PF_INET SOCK_STREAM 0 in
    let host = Unix.gethostbyname hostname in
    let ip_addr = host.h_addr_list.(0) in
    let addr = ADDR_INET (ip_addr, port_num) in
    Unix.connect s addr;
    debug "connect to somebody";
    let in_ch = in_channel_of_descr s in
    let out_ch = out_channel_of_descr s in
    in_ch, out_ch

  let rec accept_adhoc_rec ad s waiting =
    let corres, oth = match ad with
      | SEND -> waiting.send_q, waiting.recv_q
      | RECEIVE -> waiting.recv_q, waiting.send_q 
    in
    if not (Queue.is_empty corres) then Queue.pop corres
    else
      let in_ch, out_ch = accept_sock s in
      debug "to see SEND or RECEIVE";
      try
        if (Marshal.from_channel in_ch : sock_kind) = ad then 
          in_ch, out_ch
        else begin
          Queue.push (in_ch, out_ch) oth;
          accept_adhoc_rec ad s waiting end
      with
        | End_of_file ->
            print_error Channel_no_identification;
            accept_adhoc_rec ad s waiting
        | Failure f when f = "input_value: truncated object" ->
            print_error Channel_no_identification;
            accept_adhoc_rec ad s waiting

  let accept_adhoc ad s waiting =
    Mutex.lock waiting.m;
    let in_ch, out_ch = accept_adhoc_rec ad s waiting in
    Mutex.unlock waiting.m; 
    in_ch, out_ch

  let new_client ad s in_cl waiting =
    debug "new client";
    shutdown (descr_of_in_channel in_cl) SHUTDOWN_ALL;
    close_in in_cl;
    accept_adhoc ad s waiting

  let rec commu_with_send s in_cl out_ser waiting =
    debug "commu_with_send"; 
    let new_client () = new_client SEND s in_cl waiting in
    let in_cl =
      try
        match (Marshal.from_channel in_cl : 'a put_msg) with
        | PutEnd -> fst @@ new_client ()
        | Msg obj ->
            (* Si le programme fonctionne correctement, cette ligne ne peut 
               jamais être la source d'une erreur car out_ser est un pipe qui 
               est parfaitement controlé par le neoud lui-même *)
            Marshal.to_channel out_ser obj [Marshal.Closures];
            flush out_ser; in_cl
      with 
        | End_of_file -> 
            print_error Channel_in_invalid;
            (* shutdown cannot be used in this case *)
            fst @@ accept_adhoc SEND s waiting
        | Failure f when f = "input_value: truncated object" ->
            print_error Channel_in_invalid;
            fst @@ accept_adhoc SEND s waiting
    in
    commu_with_send s in_cl out_ser waiting

  let rec commu_with_recv s in_cl out_cl in_ser waiting =
    debug "commu_with_recv"; 
    let new_client () = new_client RECEIVE s in_cl waiting in
    let in_cl, out_cl = 
      try 
        match (Marshal.from_channel in_cl : get_msg) with
        | GetEnd -> new_client ()
        | Get ->
            (* c.f. avant, n'est pas censée être une source d'erreur *) 
            let obj = Marshal.from_channel in_ser in
            Marshal.to_channel out_cl obj [Marshal.Closures];
            flush out_cl; in_cl, out_cl
      with
        | End_of_file ->
            print_error Channel_request_invalid;
            accept_adhoc RECEIVE s waiting
        | Failure f when f = "input_value: truncated object" ->
            print_error Channel_request_invalid;
            accept_adhoc RECEIVE s waiting
        | Sys_error e when e = "Connection reset by peer" ->
            print_error Channel_out_reset;
            accept_adhoc RECEIVE s waiting
    in
    commu_with_recv s in_cl out_cl in_ser waiting
  
end



module Net: S = struct

  open Prot

  type channel = 
    { port_num : int ; host : string ; 
      mutable sock : (sock * sock_kind) option ; }

  module CSet = 
    Set.Make(struct type t = channel let compare = compare end)
  
  type distributor = out_channel option
  
  type 'a process = 
    { run: CSet.t -> distributor -> 'a * CSet.t; step: 'a process_step }
  
  and _ process_step =
    | Atom: 'a process_step
    | Bind: ('b -> 'a process) -> 'a process_step
  
  type 'a in_port = channel
  type 'a out_port = channel

  let computer_queue = Queue.create ()
  let add_self = ref false
  let doco_mutex = Mutex.create ()
  
  let hostname = Unix.gethostname ()
  let init_port = ref 1024
  let curr_port = ref 0


  let new_channel () = 
    debug "new_channel";

    let rec listen_incr () =
      try 
        incr curr_port;
        listen_port !curr_port
      with 
        | Unix_error(EACCES, _, _)
        | Unix_error(EADDRINUSE, _, _)
        | Unix_error(EADDRNOTAVAIL, _, _) -> listen_incr ()
    in
    let s = listen_incr () in
    
    let waiting = create_waiting () in
    let in_ser, out_ser = Unix.pipe () in
    ignore ( 
      Thread.create (Unix.handle_unix_error (fun () ->
        debug "send thread";
        let in_send_cl, _ = accept_adhoc SEND s waiting in
        commu_with_send
        s in_send_cl (out_channel_of_descr out_ser) waiting)) (),
      Thread.create (Unix.handle_unix_error (fun () ->
        debug "recv thread";
        let in_recv_cl, out_recv_cl = accept_adhoc RECEIVE s waiting in
        commu_with_recv 
        s in_recv_cl out_recv_cl (in_channel_of_descr in_ser) waiting)) ());
    
    (* On fait attention au fait que ch1 et ch2 sont différents! *)
    let ch1 = { port_num = !curr_port ; host = hostname ; sock = None } in
    let ch2 = { port_num = !curr_port ; host = hostname ; sock = None } in
    debug "leave_new_channel"; 
    ch1, ch2


  let put_run v c opened_ports _ =
    debug "put_something";
    begin 
    try
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
      flush out_ch
    with
      | Unix_error (err, _, _) ->
          print_error @@ Put_channel_no_connect
            (c.host, c.port_num, Unix.error_message err);
          Thread.exit ()
      | Sys_error err_msg ->
          print_error @@ Put_channel_no_connect (c.host, c.port_num, err_msg);
          Thread.exit () 
    end;
    () , CSet.add c opened_ports

  let put v c = { run = put_run v c ; step = Atom }


  let get_run (c:'a in_port) opened_ports _ =
    debug "get_from_channel";
    let res : 'a option ref = ref None in
    begin
    try
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
      res := Some (Marshal.from_channel in_ch)
    with
      | End_of_file ->
          print_error @@ Get_channel_invalid (c.host, c.port_num);
          Thread.exit ()
      | Failure f when f = "input_value: truncated object" ->
          print_error @@ Get_channel_invalid (c.host, c.port_num);
          Thread.exit ()
      | Unix_error (err, _, _) ->
          print_error @@ Get_channel_no_connect
            (c.host, c.port_num, Unix.error_message err);
          Thread.exit ()
      | Sys_error err_msg ->
          print_error @@ Get_channel_no_connect (c.host, c.port_num, err_msg);
          Thread.exit ()
    end;
    match !res with
    | Some a -> a, CSet.add c opened_ports
    | None -> assert false

  let get c = { run = get_run c ; step = Atom }


  let close_port port = match port.sock with
    | None -> ()
    | Some ((in_ch, out_ch), sock_kind) ->
        debug "try to close a port";
        begin
          try
            match sock_kind with
            | SEND -> Marshal.to_channel out_ch PutEnd []
            | RECEIVE -> Marshal.to_channel out_ch GetEnd [] 
          with Sys_error err_msg ->
            print_error @@ Close_port_err err_msg
        end;
        flush out_ch; close_out out_ch;
        port.sock <- None
  

  let rec send_one_process proc =
    if Queue.is_empty computer_queue then
      if !add_self = false then
        begin
          Queue.push (hostname, !init_port) computer_queue;
          add_self := true
        end
      else
        begin
          print_error No_computer;
          exit 2
        end;
    let exec_comp, corr_port = Queue.pop computer_queue in
    debug @@ "before_connect " ^ exec_comp ^ " " ^ (string_of_int corr_port);
    try
      let in_ch, out_ch = easy_connect exec_comp corr_port in
      debug "after_connect";
      Marshal.to_channel out_ch (Msg proc) [Marshal.Closures];
      flush out_ch;
      Queue.push (exec_comp, corr_port) computer_queue; 
      exec_comp, in_ch
    with
      | Not_found ->
          print_error @@ Proc_dist_no_host exec_comp;
          send_one_process proc
      | Unix_error (err, _, _) ->
          print_error @@ Proc_dist_no_connect 
            (exec_comp, corr_port, Unix.error_message err);
          send_one_process proc
      | Sys_error err_msg ->
          print_error @@ Proc_dist_no_connect (exec_comp, corr_port, err_msg);
          send_one_process proc

  (* penser à utiliser mutex pour cette fonction *)
  let send_processes = 
    List.fold_left
      (fun in_lis proc -> (send_one_process proc, proc) :: in_lis) []


  let doco_run l opened_ports _ =
    debug "doco";
    CSet.iter close_port opened_ports;
    debug "finish_close_ports";
    Mutex.lock doco_mutex;
    let in_proc_lis = send_processes l in
    Mutex.unlock doco_mutex;
    debug "finish_send_procs";
    let rec wait_finished in_proc_lis new_wait = 
      match in_proc_lis, new_wait with
      | [], [] -> ()
      | [], _ -> wait_finished (List.rev new_wait) []
      | ((comp, ch), proc)::ips, _ ->
          (* On vérifie l'état de chaque processus tour à tour, chacun pour
           * une seconde. *)
          let rec select_rec () =
            try
              Unix.select [Unix.descr_of_in_channel ch] [] [] 1.
            with
              Unix_error (err, _, _) ->
                print_error @@ Wait_finish (Unix.error_message err);
                select_rec ()
          in
          let rd, _, _ = select_rec () in
          let inch_proc = match rd with
          | [] -> [(comp, ch), proc]
          | _ ->
              begin
                try
                  match (Marshal.from_channel ch : 'a put_msg) with
                  | Msg proc' ->
                      debug "process feedback from children";
                      [(comp, ch), proc']
                  | PutEnd ->
                      shutdown (descr_of_in_channel ch) SHUTDOWN_ALL;
                      close_in ch;
                      debug "one process finished"; []
                with 
                  | End_of_file ->
                      print_error @@ Doco_peer_reset comp;
                      shutdown (descr_of_in_channel ch) SHUTDOWN_ALL;
                      close_in ch; send_processes [proc]
                  | Failure f when f = "input_value: truncated object" ->
                      print_error @@ Doco_peer_reset comp;
                      shutdown (descr_of_in_channel ch) SHUTDOWN_ALL;
                      close_in ch; send_processes [proc]
              end;
          in wait_finished ips @@ inch_proc@new_wait
    in
    wait_finished in_proc_lis [];
    (), CSet.empty

  let doco l = { run = doco_run l ; step = Atom }

    
  let return v =
    debug "return"; 
    { run = (fun opened_ports _ -> v, opened_ports) ; step = Atom }

  let rec bind_run p f opened_ports distributor =
    debug "bind";
    let res, opened_ports' = p.run opened_ports distributor in
    let next_proc = bind_step p f res in
    begin
      match distributor with
      | None -> ()
      | Some out_ch ->
          try
            Marshal.to_channel out_ch (Msg next_proc) [Marshal.Closures];
            flush out_ch
          with Sys_error err_msg ->
            print_error @@ Dist_shutdown err_msg;
            Thread.exit ()
    end;
    f res opened_ports' distributor

  and bind_step: type t. 'a process -> ('a -> 'b process) -> t -> 'b process = 
    fun p f a -> 
      match p.step with
      | Atom -> f a
      | Bind step -> bind (step a) f

  and bind p f =
    { run = bind_run p f ; step = Bind (bind_step p f) }


  let run_proc_thread ((proc : unit process), out_ch) =
    debug "try to run a proc";
    let (), opened_ports = proc.run CSet.empty (Some out_ch) in
    debug "this process end";
    debug @@ (string_of_int @@ CSet.cardinal opened_ports) ^ " port(s)";
    CSet.iter close_port opened_ports;
    debug "and close ports";
    (* Si on n'a pas réussi à envoyer PutEnd, il doit y avoir une errer
     * quelque part mais on n'y peut rien faire, le processus termine de 
     * toute façon *)
    Marshal.to_channel out_ch PutEnd [];
    flush out_ch; close_out out_ch;
    Thread.exit ()

  let listen_thread () =
    let s = try
      listen_port !init_port 
    with Unix_error (err, _, _) ->
      print_error @@ Main_listen (!init_port, Unix.error_message err);
      exit 1 in
    let rec accept_proc () =
      debug "new accept";
      try
        let in_ch, out_ch = accept_sock s in
        debug "accept something";
        match (Marshal.from_channel in_ch : 'a put_msg) with
        | PutEnd -> 
            debug "should terminate";
            exit 0  (* on termine le programme, pas que le thread *)
        | Msg (proc : unit process) -> 
            debug "get process";
            ignore (Thread.create (fun () ->
              Unix.handle_unix_error 
              run_proc_thread (proc, out_ch)) ());
            accept_proc ()
      with
        | End_of_file ->
            print_error Listen_invalid;
            accept_proc ()
        | Failure f when f = "input_value: truncated object" ->
            print_error Listen_invalid;
            accept_proc ()
        | Unix_error (err, _, _) ->
            print_error @@ Listen_accept_fail (Unix.error_message err);
            accept_proc ()

    in
    accept_proc ()

  
  let wait = ref false
  let config_file = ref "network.config"
  
  let usage = "usage: ^ Sys.argv.(0)" ^ " [option]"
  let options = 
    [ "-wait", Arg.Set wait, 
      "must be used by all the peers except the principal one";
      "-port", Arg.Set_int init_port,
      "specify the main port that is used to communicate with other
       computers (default: the port 1024), should be the same with the one 
       given in the configuration file";
      "-config", Arg.Set_string config_file,
      "the name of the configuration file for the network setup" ] 
  

  let run_aux e =

    let new_argv = Array.make (Array.length Sys.argv) "" in
    let new_argv_ind = ref 0 in

    let update_new_argv str =
      new_argv.(!new_argv_ind) <- str;
      incr new_argv_ind
    in
    update_new_argv Sys.argv.(0);

    let current = ref 0 in

    let rec rec_parse () =
      try 
        Arg.parse_argv ~current Sys.argv options 
          (fun str -> update_new_argv str) usage
      with Arg.Bad _ | Arg.Help _ -> 
        update_new_argv (Sys.argv.(!current)); rec_parse ()
    in
    rec_parse ();
    Array.blit new_argv 0 Sys.argv 0 (Array.length Sys.argv);

    let conf = open_in !config_file in
    let rec add_peer in_ch line_num =
      try
        let peer = input_line in_ch in
        debug peer;
        begin 
          match Str.split (Str.regexp "[ \t]+") peer with
          | [] -> ()
          | [compu] -> 
              (* Utilise le port 1024 par défault *)
              Queue.push (compu, 1024) computer_queue
          | compu::port::_ -> 
              try 
                Queue.push (compu, int_of_string port) computer_queue
              with Failure f when f = "int_of_string" ->
                print_error @@ Config_wrong_format line_num 
        end;
        add_peer in_ch @@ line_num + 1
      with End_of_file -> ()
    in
    add_peer conf 1;
    curr_port := !init_port;

    if !wait then handle_unix_error listen_thread () 
    
    else
      ignore (Thread.create (handle_unix_error listen_thread) ());
      debug "before exe";
      let res, opened_ports = e.run CSet.empty None in
      CSet.iter close_port opened_ports;
      debug "program should terminate";
      debug @@ string_of_int @@ Queue.length computer_queue;
      Queue.iter
        (fun (computer, port) -> 
          if (computer, port) <> (hostname, !init_port) then
            begin
              try
                let _, out_ch = easy_connect computer port in
                Marshal.to_channel out_ch PutEnd [];
                debug "send PutEnd to terminate a program";
                flush out_ch; close_out out_ch
              with 
                | Unix_error (err, _, _) ->
                    print_error @@ Terminate_program 
                      (computer, port, Unix.error_message err)
                | Sys_error err_msg ->
                    print_error @@ Terminate_program (computer, port, err_msg)
            end
          else
            add_self := true) computer_queue;
      res

  let run e = Unix.handle_unix_error run_aux e

end
