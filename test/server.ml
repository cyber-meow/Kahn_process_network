
open Unix

let rec in_to_out in_ch out_ch =
  try
    let c = input_char in_ch in
    output_char out_ch c;
    flush out_ch;
    in_to_out in_ch out_ch
  with End_of_file ->
    in_to_out in_ch out_ch

let s = socket PF_INET SOCK_STREAM 0

let server_name = gethostname ()
let ip_addr = inet_addr_any
let port = 12345
let addr = ADDR_INET (ip_addr, port)

let () = bind s addr
let () = listen s 20

let s_cl, addr_cl = accept s

let in_ch = in_channel_of_descr s_cl
let out_ch = out_channel_of_descr s_cl
let rec f in_ch = Format.printf "%c@?" (input_char in_ch); f in_ch
let rec g out_ch = output_string out_ch "hello\n"; flush out_ch; g out_ch

