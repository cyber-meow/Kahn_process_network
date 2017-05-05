
module Vector = struct

  type vector = float array

  let vector_zero n = Array.make n 0.

  let (++) = Array.map2 (+.)
  let (--) = Array.map2 (-.)

  let norm2 vect = 
    Array.fold_left (+.) 0. (Array.map (fun x -> x *. x) vect)

  let dis_square vect1 vect2 = norm2 @@ vect1--vect2

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

  let worker iter qin qout =
    let rec step points i =
      if i = iter then K.return ()
      else
        K.get qin >>=
        fun centers ->
          let num_sum = cal_dist points centers in
          K.put num_sum qout >>=
        fun () -> step points (i+1)
    in
    K.get qin >>= fun points -> step points 0

  (* Communiquer avec plusieurs canaux *)

  let rec put_chs out_msg = function
    | [] -> K.return ()
    | qo::qos -> K.put out_msg qo >>= fun () -> put_chs out_msg qos

  let rec get_chs in_msgs = function
    | [] -> K.return in_msgs
    | qi::qis -> K.get qi >>= fun in_msg -> get_chs (in_msg::in_msgs) qis

  (* Le patron distribue les points et fait la somme pour les données reçus *)

  let master iter qins qouts init_centers =
    let d = Array.length init_centers.(0) in
    let k = Array.length init_centers in
    let rec step centers i =
      if i = iter then K.return centers
      else
        put_chs centers qouts >>=
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

  (* Diviser l'ensemble de points en n partie d'à peu près même tailles *)

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

  (* random_permu, init_center, kmeans *)

end

