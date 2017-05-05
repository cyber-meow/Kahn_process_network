
(************************************************************************)
(*                                                                      *)
(* A distributed pong game KPN implementation                           *)
(*                                                                      *)
(* Modified from the TP code of the ENS L3 system course                *)
(*                                                                      *)
(* The game must be played on exactly two computers.                    *)
(* On the first computer the program is lauched with the option -wait   *)
(* On the second computer the program is then launched directly with    *)
(* the parameters that are related to the game (see below)              *)
(*                                                                      *)
(************************************************************************)

module K = Kahn_network.Net
module Lib = Kahn.Lib(K)
open Lib


(* - Configuration - *)

let config_parse () =
  let _ = Random.self_init () in
  let length = ref 800 in
  let width = ref 600 in
  let pad_size = ref 100 in
  let k_pad = ref 1. in
  let vx, vy = let a = Random.float 3.14 in ref (cos a), ref (sin a) in
  let k_ball = ref 2. in
  let spec =
    [ "-length", Arg.Set_int length, "set the length of the game area";
      "-width", Arg.Set_int width, "set the width of the game area";
      "-pad", Arg.Set_int pad_size, "set the size of the pad";
      "-pspeed", Arg.Set_float k_pad, "speed factor for the pad";
      "-alpha", Arg.Float (fun a -> vx := cos a; vy := sin a),
         "set the initial angle";
      "-speed", Arg.Set_float k_ball, "speed factor for the ball"; 
      "-port", Arg.Int (fun _ -> ()), 
      "specify the main port that is used to commnicate with other 
        computers (default: the port 1024), should be the same with the one
        given in the Configuration file";
      "-wait", Arg.Unit (fun () -> ()), "used by the second player";
      "-configfile", Arg.String (fun _ -> ()), "name of Configuration file" ]
  in
  let usage =
    ("Usage: "^Sys.argv.(0)^" [options] \n"^
     "Options:")
  in
  Arg.parse spec 
    (fun s -> if s <> "" then (Arg.usage spec usage; exit 1)) usage;
  vx := !k_ball *. !vx;
  vy := !k_ball *. !vy;
  (float_of_int !length, float_of_int !width,
   !pad_size, float_of_int !pad_size /. 2., 10. *. !k_pad,
   !vx, !vy, !k_ball)


(* - Type definitions - *)

type player = P1 | P2

type direction = Left | Right

type state =
    { pad1: float;
      pad2: float;
      ball_p: float * float;
      ball_v: float * float; }

exception Win of player


(* - Game state control - *)

let move_pad pad_speed player pre_y dir =
  match player, dir with
  | (P1, Some Left)
  | (P2, Some Right) -> pre_y +. pad_speed
  | (P1, Some Right)
  | (P2, Some Left) -> pre_y -. pad_speed
  | _, None -> pre_y

let move_ball length width pad_size_2 
    (pre_vx, pre_vy) (pre_x, pre_y) pad1 pad2 =
  let pong pad = pad -. pad_size_2 <= pre_y && pre_y <= pad +. pad_size_2 in
  let vx =
    if pre_x <= 0. && pong pad1 || pre_x >= length && pong pad2 then -. pre_vx
    else pre_vx
  in
  let vy =
    if pre_y <= 0. || pre_y >= width then -. pre_vy
    else pre_vy
  in
  let x, y = (pre_x +. vx,  pre_y +. vy) in
  (vx, vy), (x, y)

let step length width pad_size_2 pad_speed pre_state (act1, act2) =
  let pad1 = move_pad pad_speed P1 pre_state.pad1 act1 in
  let pad2 = move_pad pad_speed P2 pre_state.pad2 act2 in
  let v, p =
    move_ball length width pad_size_2 pre_state.ball_v pre_state.ball_p 
    pre_state.pad1 pre_state.pad2
  in
  { pad1 = pad1; pad2 = pad2; ball_v = v; ball_p = p; }

let win_or_not length v_max state =
  if fst state.ball_p < -. v_max then 
    begin 
      Format.printf "Player 2 wins!@."; Unix.sleep 2; exit 0 
    end;
  if fst state.ball_p > length +. v_max then 
    begin 
      Format.printf "Player 1 wins!@."; Unix.sleep 2; exit 0 
    end


(* - Affichage - *)

let init_graph length width =
  Graphics.open_graph
    (Printf.sprintf " %dx%d" (int_of_float length) (int_of_float width));
  Graphics.auto_synchronize false

let draw_pad length pad_size pad_size_2 player pos =
  let pad_width = 4 in
  let x =
    match player with
    | P1 -> 0
    | P2 -> int_of_float length - pad_width
  in
  let y = int_of_float (pos -. pad_size_2) in
  Graphics.fill_rect x y pad_width pad_size

let draw_ball (x, y) =
  let x, y = int_of_float x, int_of_float y in
  Graphics.fill_circle x y 5

let draw length pad_size pad_size_2 state =
  Graphics.clear_graph ();
  draw_ball state.ball_p;
  draw_pad length pad_size pad_size_2 P1 state.pad1;
  draw_pad length pad_size pad_size_2 P2 state.pad2;
  Graphics.synchronize ()


(* - Interact with users - *)

let sleep n = Unix.sleepf n

let actions_of_char c =
  match c with
  | 'd' -> Some Left
  | 'f' -> Some Right
  | 'q' -> exit 0
  | _ -> None

let graphics_read_pads () =
  sleep 0.01;
  if Graphics.key_pressed () then actions_of_char (Graphics.read_key ())
  else None


(* - Client server communication - *)

let player_client length width pad_size pad_size_2 v_max qin qout =
  let rec player_client () =
    K.get qin >>= 
    fun state -> 
      draw length pad_size pad_size_2 state;
      win_or_not length v_max state;
      K.put (graphics_read_pads ()) qout >>=
    fun () -> player_client ()
  in
  delay (init_graph length) width >>= fun () -> player_client ()

let player_server length width pad_size pad_size_2 
    pad_speed v_max init_state qin qout =
  let rec player_server pre_state =
    K.put pre_state qout >>=
    fun () -> 
      draw length pad_size pad_size_2 pre_state;
      win_or_not length v_max pre_state;
      let action_p2 = graphics_read_pads () in K.get qin >>=
    fun action_p1 ->
      let state = step length width pad_size_2 
                  pad_speed pre_state (action_p1, action_p2) in
      player_server state
  in
  delay (init_graph length) width >>= fun () -> player_server init_state


(* - Launch the program - *)

let main =
  delay config_parse () >>= 
  fun (length, width, pad_size, pad_size_2, pad_speed, 
       vx_init, vy_init, v_max) ->
    let init =
      { pad1 = width /. 2.;
        pad2 = width /. 2.;
        ball_p = (length /. 2., width /. 2.);
        ball_v = (vx_init, vy_init); }
    in
    delay K.new_channel () >>=
  fun (qi1, qo1) -> K.return (K.new_channel ()) >>=
  fun (qi2, qo2) -> 
    K.doco 
    [ player_client length width pad_size pad_size_2 v_max qi1 qo2;
      player_server length width pad_size pad_size_2 pad_speed 
      v_max init qi2 qo1]

let () = K.run main
