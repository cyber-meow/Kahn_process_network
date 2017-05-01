
module Mandelbrot (K : Kahn.S) = struct

  module K = K
  module Lib = Kahn.Lib(K)
  open Lib

  type zone = 
    { lb: float * float ; rt: float * float ; width: int ; height: int }

  let w = 800
  let h = 600
  
  let w_div = 5
  let h_div = 4
  
  let k = 100

  let norm2 x y = x *. x +. y *. y

  (* a + bi est le nombre complex *)
  let mandelbrot a b : (bool K.process) =
    let rec mandel_rec x y i =
      if i = k || norm2 x y > 4. then K.return (i = k)
      else
        K.return (x *. x -. y *. y +. a) >>=
        fun x' -> K.return (2. *. x *. y +. b) >>=
        fun y' -> mandel_rec x' y' (i+1)
    in
    mandel_rec 0. 0. 0


  let draw_partial zone qo =
    
    let {lb = (x1, y1); rt = (x2, y2); width; height} = zone in
    let delta_x = (x2 -. x1) /. (float_of_int w) in
    let delta_y = (y2 -. y1) /. (float_of_int h) in
    
    let next_point a b =
      if a +. delta_x < x2 then Some (a +. delta_x, b)
      else if b +. delta_y < y2 then Some (x1 +. delta_x/.2., b +. delta_y)
      else None
    in
   
   let rec test_point a b =
      mandelbrot a b >>=
        fun bo -> (if bo then (K.put (Some (a, b))
        qo) else K.return ()) >>=
      fun point_lis' -> 
        match next_point a b with
        | Some (a', b') -> test_point a' b'
        | None -> Format.printf "putNone@."; K.put None qo
    in
    test_point (x1 +. delta_x/.2.) (y1 +. delta_y/.2.)
    

  let divide_image (x1, y1) (x2, y2) =
    
    let width = w / w_div in
    let height = h / h_div in
    let delta_x = (x2 -. x1) /. (float_of_int w_div) in
    let delta_y = (y2 -. y1) /. (float_of_int h_div) in
    
    let image x1 y1 = 
      {lb = (x1, y1); rt = (x1 +. delta_x, y1 +. delta_y); width; height} in
    
    let rec one_image i j zone_lis =
      let x1' = x1 +. delta_x *. (float_of_int i) in
      let y1' = y1 +. delta_y *. (float_of_int j) in
      let l' = (image x1' y1')::zone_lis in
      if i = w_div - 1 then
        if j = h_div - 1 then l'
        else one_image 0 (j+1) l'
      else one_image (i+1) j l'
    in
    K.return (one_image 0 0 [])


  let create_channels n =
    let rec creating i chs =
      if i = n then chs
      else creating (i+1) (K.new_channel()::chs)
    in
    creating 0 []

  let plot_in qin_lis = 
    let rec plot_in_rec = function
      | [] -> K.return ()
      | qi::qis ->
          K.get qi >>= fun point -> match point with
            | Some (a, b) ->
                let a_int = int_of_float ((a+.2.) *. 200.) in
                let b_int = int_of_float ((b+.1.5) *. 200.) in
                Graphics.plot a_int b_int; plot_in_rec (qis@[qi])
            | None -> plot_in_rec qis
    in
    K.return (Graphics.open_graph (Format.sprintf " %dx%d" w h)) >>=
    (fun () -> plot_in_rec qin_lis)


  let distribute_image (x1, y1) (x2, y2) =
    delay create_channels (h_div * w_div) >>=
    fun chs -> divide_image (x1, y1) (x2, y2) >>=
    fun zones ->
      let workers = 
        List.map2 (fun z ch -> draw_partial z (snd ch)) zones chs in
      K.doco ((plot_in (List.rev (List.map fst chs)))::workers) >>=
    (fun () -> K.return (Unix.pause ()))


  let main =
    delay K.new_channel () >>=
    fun (q_in, q_out) -> 
      K.doco 
      [ draw_partial 
        { lb = (-2., -1.5); rt = (2., 1.5) ; height = h ; width = w } q_out ; 
        plot_in [q_in] ] >>=
    (fun () -> K.return (Unix.pause ()))

end

module Mandel = Mandelbrot(Kahn_seq.Seq)

let () = Mandel.K.run (Mandel.distribute_image (-2., -1.5) (2., 1.5))
