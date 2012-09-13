open Lwt
open Lwt_io
open Lwt_unix

open Intersango_common
    
module Book = struct
  module IntMap = Map.Make(
    struct 
      type t = int
      let compare = Pervasives.compare 
    end)
    
  (** A book represent the depth for one currency, and one order
      kind *)
  type t = int IntMap.t
    
  let (empty:t) = IntMap.empty
    
  let make_books_fun () =
    let books = Hashtbl.create 10 in
    let add (curr:Currency.t) price amount = 
      let book =
        try Hashtbl.find books curr 
        with Not_found -> empty in
      let new_book =
        if IntMap.mem price book then 
          let old_amount = IntMap.find price book in
          IntMap.add price (old_amount + amount) book
        else IntMap.add price amount book
      in Hashtbl.replace books curr new_book in
    let print () =
      let print_one book = IntMap.iter 
        (fun rate amount -> Printf.printf "(%f,%f) " 
          (Satoshi.to_btc_float rate)
          (Satoshi.to_btc_float amount)) book in
      Hashtbl.iter (fun curr book -> 
        Printf.printf "Currency: %s\n" (Currency.to_string curr);
        print_one book; print_endline "";
          
      ) books
    in (add, print)
    
  let add_to_bid_books, print_bid_books = make_books_fun ()
  let add_to_ask_books, print_ask_books = make_books_fun ()
end

open Intersango_parser
module Parser = Parser(Book)

let print_to_stdout (ic, oc) : unit Lwt.t =
  let buf = Bi_outbuf.create 100 in
  let rec print_to_stdout () =
    return ic
    >>= fun c -> read_line c
    >>= fun str -> 
    Parser.update_books (Yojson.Safe.from_string ~buf str);
    printf "%s\n" str
    >>= fun () -> print_to_stdout ()
  in print_to_stdout ()
     
let with_connection url port f =
  gethostbyname url >>=
    fun e -> Lwt_io.with_connection 
  (ADDR_INET (e.h_addr_list.(0), port)) f
  
let () =
  Sys.catch_break true;
  try
    let threads_to_run =
      [(with_connection "db.intersango.com" 1337 print_to_stdout)] in
    Lwt.join threads_to_run |> Lwt_main.run
  with Sys.Break ->
    print_endline "Bids"; Parser.print_bid_books ();
    print_endline "Asks"; Parser.print_ask_books ()
    
    
