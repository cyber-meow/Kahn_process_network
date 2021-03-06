
(****************************************************************************)
(*                                                                          *)
(* Parallel computing of the Mandelbrot set in a KPN model                  *)
(*                                                                          *)
(* The whole image is divided into several different zones and each process *)
(* is responsible for the computation of one zone, only one display.        *)
(* Please see the end of the code body for a detailed description of        *)
(* command line arguments.                                                  *)
(*                                                                          *)
(****************************************************************************)


module Mandelbrot (K : Kahn.S) = struct

  module K = K
  module Lib = Kahn.Lib(K)
  open Lib

  type zone = 
    { lb: float * float ; rt: float * float ; width: int ; height: int }

  type draw_msg = Point of float * float | Pass | End

  let w = ref 800
  let h = ref 600
  
  let w_div = ref 5
  let h_div = ref 4
  
  let iter = ref 100

  let norm2 x y = x *. x +. y *. y

  (* a + bi est le nombre complex *)
  let mandelbrot a b iter_n : (bool K.process) =
    let rec mandel_rec x y i =
      if i = iter_n || norm2 x y > 4. then K.return (i = iter_n)
      else
        K.return (x *. x -. y *. y +. a) >>=
        fun x' -> K.return (2. *. x *. y +. b) >>=
        fun y' -> mandel_rec x' y' (i+1)
    in
    mandel_rec 0. 0. 0


  let draw_partial zone iter_n qo =
    
    let {lb = (x1, y1); rt = (x2, y2); width; height} = zone in
    let delta_x = (x2 -. x1) /. (float_of_int width) in
    let delta_y = (y2 -. y1) /. (float_of_int height) in
    
    let next_point a b =
      if a +. delta_x < x2 then Some (a +. delta_x, b)
      else if b +. delta_y < y2 then Some (x1 +. delta_x/.2., b +. delta_y)
      else None
    in
   
   let rec test_point a b =
      mandelbrot a b iter_n >>=
      fun bo -> (if bo then (K.put (Point (a, b)) qo) else K.put Pass qo) >>=
      fun point_lis' -> 
        match next_point a b with
        | Some (a', b') -> test_point a' b'
        | None -> K.put End qo
    in
    test_point (x1 +. delta_x/.2.) (y1 +. delta_y/.2.)
    

  let divide_image (x1, y1) (x2, y2) w h w_div h_div =
    
    if w mod w_div <> 0 then
      begin
        Format.eprintf "%s: wd must be a factor of w@." Sys.argv.(0); 
        exit 1
      end;
    if h mod h_div <> 0 then
      begin
        Format.eprintf "%s: hd must be a factor of h@." Sys.argv.(0); 
        exit 1
      end;
      
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

  let plot_in w h qin_lis = 
    let w_convert = float_of_int w /. 4. in
    let h_convert = float_of_int h /. 3. in
    let rec plot_in_rec qis qis2 =
      match qis, qis2 with
      | [], [] -> K.return ()
      | [], qis -> plot_in_rec (List.rev qis) []
      | qi::qis, qis2 ->
          K.get qi >>= fun point -> match point with
            | Point (a, b) ->
                let a_int = int_of_float ((a+.2.) *. w_convert) in
                let b_int = int_of_float ((b+.1.5) *. h_convert) in
                Graphics.plot a_int b_int; plot_in_rec qis (qi::qis2)
            | Pass -> 
                plot_in_rec qis (qi::qis2)
            | End ->
                plot_in_rec qis qis2
    in
    (* Il est très important de mettre delay ici car on veut que
       la fenêtre d'affichage soit ouverte dans le processus *)
    delay Graphics.open_graph (Format.sprintf " %dx%d" w h) >>=
    fun () -> plot_in_rec qin_lis [] >>=
    fun () -> K.return (ignore (Graphics.read_key ()))


  let distribute_image (x1, y1) (x2, y2) w h w_div h_div iter_n =
    delay create_channels (h_div * w_div) >>=
    fun chs -> divide_image (x1, y1) (x2, y2) w h w_div h_div >>=
    fun zones ->
      let workers = 
        List.map2 (fun z ch -> draw_partial z iter_n (snd ch)) zones chs in
      K.doco ((plot_in w h (List.map fst chs))::workers)


  let usage = "Usage: " ^ Sys.argv.(0) ^ " [option] \nOptions:"

  let options =
    [ "-h", Arg.Set_int h, 
      " number of pixels for the height (by default 600)" ;
      "-w", Arg.Set_int w, 
      " number of pixels for the width (by default 800)" ;
      "-wd", Arg.Set_int w_div, 
      Format.sprintf
      " number of divisions of width for parallel processing, "
      ^ "must divide w\n" ^ String.make 10 ' ' ^ "(by default 5)" ;
      "-hd", Arg.Set_int h_div, 
      " number of divisions of height for parallel processing, " ^
      " must divide h\n" ^ String.make 10 ' ' ^ "(by default 4)" ;
      "-iter", Arg.Set_int iter,
      " number of iterations used to compute the Mandelbrot set" ]

  let parse_cmd () =
    Arg.parse (Arg.align options) (fun _ -> ()) usage;
    let args = 
      [!h, "h"; !w, "w"; !w_div, "wd"; !h_div, "hd"; !iter, "iter"] 
    in
    try
      let invalid_arg = List.find (fun (value, _) -> value <= 0) args in
      Format.eprintf 
        "%s: %s can only take positive value@." 
        Sys.argv.(0) @@ snd invalid_arg;
      exit 1
    with Not_found -> ()

  let main =
    delay parse_cmd () >>=
    fun () -> distribute_image (-2., -1.5) (2., 1.5) !w !h !w_div !h_div !iter

end


module Mandel = Impls.Choose_impl(Mandelbrot)
let () = Mandel.run ()
