(* Configuration *)

let length, width,
    pad_size, pad_size_2, pad_speed,
    vx_init, vy_init, v_max  =
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
      "-speed", Arg.Set_float k_ball, "speed factor for the ball"; ]
  in
  let usage =
    ("Usage: "^Sys.argv.(0)^" [options] \n"^
     "Options:")
  in
  Arg.parse spec (fun _ -> Arg.usage spec usage; exit 1) usage;
  vx := !k_ball *. !vx;
  vy := !k_ball *. !vy;
  (float_of_int !length, float_of_int !width,
   !pad_size, float_of_int !pad_size /. 2., 10. *. !k_pad,
   !vx, !vy, !k_ball)

(* --------------------------------------------------------- *)

type player = P1 | P2

type direction = Left | Right

type state =
    { pad1: float;
      pad2: float;
      ball_p: float * float;
      ball_v: float * float; }

exception Win of player

(* --------------------------------------------------------- *)

let move_pad player pre_y dir =
  match player, dir with
  | (P1, Some Left)
  | (P2, Some Right) -> pre_y +. pad_speed
  | (P1, Some Right)
  | (P2, Some Left) -> pre_y -. pad_speed
  | _, None -> pre_y

let move_ball (pre_vx, pre_vy) (pre_x, pre_y) pad1 pad2 =
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

let step pre_state (act1, act2) =
  let pad1 = move_pad P1 pre_state.pad1 act1 in
  let pad2 = move_pad P2 pre_state.pad2 act2 in
  let v, p =
    move_ball pre_state.ball_v pre_state.ball_p pre_state.pad1 pre_state.pad2
  in
  { pad1 = pad1; pad2 = pad2; ball_v = v; ball_p = p; }

let play read_pads draw init_state =
  let rec play pre_state =
    let actions = read_pads () in
    let state = step pre_state actions in
    draw state;
    if fst state.ball_p < -. v_max then raise (Win P2);
    if fst state.ball_p > length +. v_max then raise (Win P1);
    play state
  in
  play init_state


(* --------------------------------------------------------- *)

let init_graph () =
  Graphics.open_graph
    (Printf.sprintf " %dx%d" (int_of_float length) (int_of_float width));
  Graphics.auto_synchronize false

let draw_pad player pos =
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

let draw state =
  Graphics.clear_graph ();
  draw_ball state.ball_p;
  draw_pad P1 state.pad1;
  draw_pad P2 state.pad2;
  Graphics.synchronize ()

(* --------------------------------------------------------- *)

let sleep n = Unix.sleepf n

let actions_of_char c =
  match c with
  | 's' -> Some Left, None
  | 'f' -> Some Right, None
  | 'j' -> None, Some Left
  | 'l' -> None, Some Right
  | 'q' -> exit 0
  | _ -> None, None

let read_pads s_p1 s_p2 () =
  Marshal.from_channel

let graphics_read_pads () =
  sleep 0.01;
  if Graphics.key_pressed () then actions_of_char (Graphics.read_key ())
  else None, None

(* --------------------------------------------------------- *)

let main =
  let init =
    { pad1 = width /. 2.;
      pad2 = width /. 2.;
      ball_p = (length /. 2., width /. 2.);
      ball_v = (vx_init, vy_init); }
  in
  init_graph ();
  try play (read_pads inch_p1 inch_p2) draw init
  with Win P1 -> Format.printf "Player 1 wins!@."
  | Win P2 -> Format.printf "Player 2 wins!@."
