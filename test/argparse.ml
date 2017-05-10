
let test = ref 0

let usage = "Usage: " ^ Sys.argv.(0) ^ " [options]"
let options = ["-t", Arg.Set_int test, "test"]

let () = Arg.parse options (fun _ -> ()) usage
