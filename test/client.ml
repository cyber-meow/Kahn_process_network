
open Unix

let s = socket PF_INET SOCK_STREAM 0
let host = gethostbyname "yuguan-UX32VD"
let ip_addr = host.h_addr_list.(0)
let port = 12345
let addr = ADDR_INET (ip_addr,port)
let () = connect s addr

let out_ch = out_channel_of_descr s
