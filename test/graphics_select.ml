
let () = Graphics.open_graph ""
let () = 
  begin
    (*Graphics.fill_rect 0 0 100 100; 
    ignore (Unix.select [Unix.stdin] [] [] 2.);*)
    (*Graphics.clear_graph ();*)
    Graphics.synchronize ();
    (*Graphics.fill_rect 0 0 100 100; *)
    ignore (Unix.select [Unix.stdin] [] [] 2.);
    (*Graphics.clear_graph ();
    Graphics.synchronize ();*)
  end
let () = Unix.pause ()
