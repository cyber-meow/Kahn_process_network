
(****************************************************************************)
(*                                                                          *)
(* Parallel k-means clustering in KPN framework                             *)
(*                                                                          *)
(* K-means clustering is a method of vector quantization, originally from   *)
(* signal processing, that is popular for cluster analysis in data mining.  *)
(* K-means clustering aims to partition n observations into k clusters in   *)
(* which each observation belongs to the cluster with the nearest mean      *)
(* serving as a prototype of the cluster.                        -Wikipidea *)
(*                                                                          *)
(* A input file that contains exactly one data point [coordinates separated *)
(* by spaces] each line should be given as the command line argument.       *)
(* For more specifications please see near line 200 of the code body.       *)
(* We use a random initilization for the clusters.                          *)
(*                                                                          *)
(****************************************************************************)


module Vector = struct

  type vector = float array

  let vector_zero n = Array.make n 0.

  let (++) = Array.map2 (+.)
  let (--) = Array.map2 (-.)

  let norm2 vect = 
    vect |> Array.map (fun x -> x *. x) |> Array.fold_left (+.) 0.

  let dis_square vect1 vect2 = vect1--vect2 |> norm2
  
  let string_of_vector vect =
    vect |> Array.map string_of_float |> Array.to_list |> 
    String.concat ", " |> Format.sprintf "(%s)"

end


module K_means (K : Kahn.S) = struct

  module K = K
  module Lib = Kahn.Lib(K)
  open Lib

  open Vector

  (* Calculer pour chaque point le cluster qu'il appartient *)

  let cal_dist points centers =
    let d = Array.length points.(0) in
    let k = Array.length centers in
    let num_sum = Array.make k (0, vector_zero d) in
    for i = 0 to Array.length points - 1 do
      let point = points.(i) in
      let min_dis2 = ref @@ dis_square point centers.(0) in
      let min_ind = ref 0 in
      for j = 1 to k-1 do
        let dis2 = dis_square point centers.(j) in
        if dis2 < !min_dis2 then
          begin
            min_ind := j;
            min_dis2 := dis2
          end;
      done;
      let num, sum = num_sum.(!min_ind) in
      num_sum.(!min_ind) <- num + 1, sum ++ point
    done;
    num_sum

  (* Chaque ouvrier fait les calculs pour une partie de points *) 

  let worker iter points qin qout =
    let rec step i =
      if i = iter then K.return ()
      else
        K.get qin >>=
        fun centers ->
          let num_sum = cal_dist points centers in
          K.put num_sum qout >>=
        fun () -> step (i+1)
    in
    step 0

  (* Communiquer avec plusieurs canaux *)

  let rec put_one_chs out_msg = function
    | [] -> K.return ()
    | qo::qos -> K.put out_msg qo >>= fun () -> put_one_chs out_msg qos

  let rec put_chs out_msgs q_outs = 
    match out_msgs, q_outs with
    | [], [] -> K.return ()
    | [], _ | _, [] -> invalid_arg "put_chs: lists not the same size"
    | m::ms, qo::qos -> K.put m qo >>= fun () -> put_chs ms qos

  let rec get_chs in_msgs = function
    | [] -> K.return in_msgs
    | qi::qis -> K.get qi >>= fun in_msg -> get_chs (in_msg::in_msgs) qis

  let create_channels k =
    let rec creating i chs =
      if i = k then chs
      else creating (i+1) (K.new_channel()::chs)
    in
    creating 0 []

  (* Le patron distribue les points et fait la somme pour les données reçus *)

  let master iter init_centers qins qouts qo_final =
    let d = Array.length init_centers.(0) in
    let k = Array.length init_centers in
    let rec step centers i =
      if i = iter then K.put centers qo_final
      else
        put_one_chs centers qouts >>=
        fun () -> get_chs [] qins >>=
        fun num_sums ->
          let num_sum' =
            List.fold_left 
              (Array.map2 (fun (n1,s1) (n2,s2) -> n1+n2, s1++s2))
              (Array.make k (0, vector_zero d)) num_sums
          in
          let centers' = 
            Array.map 
              (fun (n, vect) -> 
                let fn = float_of_int n in 
                Array.map (fun x -> x /. fn) vect)
              num_sum'
          in
          step centers' (i+1)
    in
    step init_centers 0

  (* Diviser l'ensemble de points en n partie de tailles similaires *)

  let divide_points points m =
    let n = Array.length points in
    let div_size = n/m in
    let num_bigger = n mod m * div_size in
    let rec div_array division_list curr_pos =
      if curr_pos > n then assert false
      else 
        if curr_pos = n then division_list
        else 
          let div_size = 
            if curr_pos < num_bigger then div_size + 1 else div_size in
          let new_div = Array.sub points curr_pos div_size in
          div_array (new_div::division_list) (curr_pos + div_size)
    in
    div_array [] 0

  (* In place random permutation of an array *)

  let random_permu arr =
    Random.self_init ();
    let n = Array.length arr in
    for i = 0 to n-2 do
      let k = Random.int (n-i) in
      let tmp = arr.(i) in
      arr.(i) <- arr.(i+k);
      arr.(i+k) <- tmp 
    done

  (* L'initialisation pour les centres des clusters *)

  let init_centers points k =
    Array.sub points 0 k

  (* The parallel k-means algorithm, side effect on the array points *)

  let k_means iter points dim k num_workers qo_final =
    let n = Array.length points in
    if n < k then
        invalid_arg "k_means: Cannot have more clusters than data points";
    if n < num_workers then
        invalid_arg "k_means: Must have fewer workers than data points";
    for i = 0 to n-1 do
      if Array.length points.(i) <> dim then
        invalid_arg "k_means: Dimension of data point is not as specified"
    done;
    random_permu points;
    let point_partitions = divide_points points num_workers in
    let init_centers = init_centers points k in
    let point_chs = create_channels num_workers in
    let num_sum_chs = create_channels num_workers in
    let master =
      master iter init_centers 
        (List.map fst num_sum_chs) (List.map snd point_chs) qo_final
    in
    let workers = 
      List.map2 
        (fun pset (qin, qout) -> worker iter pset qin qout) 
        point_partitions @@
        List.combine (List.map fst point_chs) (List.map snd num_sum_chs)
    in
    K.doco @@ master::workers

end


module K_means_exe (K : Kahn.S) = struct

  module K_means = K_means(K)
  module Lib = Kahn.Lib(K)

  let d = ref None
  let k = ref 8
  let iter = ref 300
  let num_workers = ref 10
  let data_file = ref None
  let output_file = ref "clusters.txt"

  let usage = 
    "Usage: " ^ Sys.argv.(0) ^ " [options] <filename>" ^
    "\nOptions:"

  let options =
    [ "-k", Arg.Set_int k,
      " number of clusters k in the algorithm (default 8)";
      "-d", Arg.Int (fun i -> d := Some i),
      " dimension of data examples (must be consistent with the data";
      "-p", Arg.Set_int num_workers,
      " number of parallel processes used in the computation (default 10)";
      "-i", Arg.Set_int iter,
      " number of iterations to run (default 300)";
      "-o", Arg.Set_string output_file,
      " name of the output file (containing cluster centers)" ]

  let parse_cmd () =
    Arg.parse (Arg.align options)
      (fun str -> if str <> "" then
        match !data_file with 
        | None -> data_file := Some str
        | _ -> Format.eprintf 
            "%s: At most one data file can be given.@." Sys.argv.(0); exit 1)
      usage
    
  let check_parse () =
    let data_file = 
      match !data_file with
      | None -> 
          Format.eprintf "%s: %s@\nuse --help for more information@."
          Sys.argv.(0) "data file name missing"; exit 1
      | Some data_file -> data_file
    in
    let args = [!k, "k"; !num_workers, "p"; !iter, "i"] in
    try
      let invalid_arg = List.find (fun (value, _) -> value <= 0) args in
      Format.eprintf 
        "%s: %s can only take positive value@."
        Sys.argv.(0) @@ snd invalid_arg; 
      exit 1
    with Not_found -> data_file

  let parse_point ?d line_num str =
    let str_sp = Array.of_list @@ Str.split (Str.regexp "[ \t]+") str in
    begin 
      match d with 
      | None -> ()
      | Some d ->
          if Array.length str_sp <> d then
          begin
            Format.eprintf 
              "%s: %s@ (expected %d but %d found)@."
              Sys.argv.(0) "inconsistent data point dimension" 
              d (Array.length str_sp);
            exit 1
          end
    end;
    try Array.map float_of_string str_sp
    with Failure str when str = "float_of_string" ->
      Format.eprintf 
        "%s: line %d of the data file, input format incorrect@." 
        Sys.argv.(0) line_num;
      exit 1
      
  let rec points_from_file ?d in_ch =
    let d, points, line_num = 
      match d with
      | None ->
          begin
            try
              let l = input_line in_ch in
              let p_vect = parse_point 0 l in
              Array.length p_vect, [p_vect], 2
            with End_of_file -> -1, [], 0
          end
      | Some d -> d, [], 1
    in
    let rec points_from_file line_num points =
      try
        let l = input_line in_ch in
        let p_vect = parse_point ~d line_num l in
        points_from_file (line_num+1) (p_vect::points)
      with End_of_file -> points
    in
    points_from_file line_num points, d

  let printout_clusters out_ch points =
    let out = Format.formatter_of_out_channel out_ch in
    Format.fprintf out "cluster centers:@\n@\n";
    Array.iter 
      (fun point -> 
        Format.fprintf out "%s@\n" @@ 
        Vector.string_of_vector point)
      points;
    Format.fprintf out "@?"

  let main = Lib.(
    delay parse_cmd () >>=
    fun () -> 
      let data_file = check_parse () in
      let in_ch = open_in data_file in
      let points, d = points_from_file ?d:!d in_ch in
      let points = Array.of_list points in
      close_in in_ch;
      K.return @@ K.new_channel () >>=
    fun (q_in, q_out) -> 
      try 
        K_means.k_means !iter points d !k !num_workers q_out >>=
        fun () -> K.get q_in >>=
        fun centers -> 
          let out_ch = open_out !output_file in
          printout_clusters out_ch centers;
          K.return (close_out out_ch)
      with Invalid_argument err_msg ->
        Format.eprintf "%s: %s@." Sys.argv.(0) err_msg; exit 10)

end


module K_means_run = Impls.Choose_impl(K_means_exe)
let () = K_means_run.run ()
