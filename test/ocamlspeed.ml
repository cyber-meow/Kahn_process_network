
let time f x =
  let t = Sys.time () in
  let fx = f x in
  Format.printf "execution time: %f sec@." (Sys.time () -.t); fx

let arr = Array.init 1000000 (fun i -> (float_of_int i) /. 1000.)
let arr2 = Array.make 1000000 0.
let lis = Array.to_list arr

let test () =
  for i = 0 to 999999 do
    arr2.(i) <- arr.(i) +. arr.(i)
  done

let rec addlis res = function
  | [] -> res
  | x::xs -> addlis ((x+.x)::res) xs

let () = ignore (time (Array.map2 (+.) arr) arr)
let () = ignore (time test ())
let () = ignore (time List.rev (addlis [] lis))
