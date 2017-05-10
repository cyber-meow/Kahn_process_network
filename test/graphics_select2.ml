
let graph () = 
  Format.printf "hello@.";
  Graphics.open_graph "";
  for i = 0 to 200 do
    Unix.sleepf 0.5;
    Graphics.plot i i
  done

let () = ignore (Thread.create graph ())

let () = ignore (Unix.select [Unix.stdin] [] [] 60.)
