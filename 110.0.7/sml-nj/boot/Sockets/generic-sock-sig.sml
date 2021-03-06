(* generic-sock-sig.sml
 *
 * COPYRIGHT (c) 1995 AT&T Bell Laboratories.
 *
 *)

signature GENERIC_SOCK =
  sig
    val addressFamilies : unit -> Socket.AF.addr_family list
	(* returns a list of the supported address families; this should include
	 * at least:  Socket.AF.inet.
	 *)

    val socketTypes : unit -> Socket.SOCK.sock_type
	(* returns a list of the supported socket types; this should include at
	 * least:  Socket.SOCK.stream and Socket.SOCK.dgram.
	 *)

  (* create sockets using default protocol *)
    val socket : (Socket.AF.addr_family * Socket.SOCK.sock_type)
	  -> ('a, 'b) Socket.sock
    val socketPair : (Socket.AF.addr_family * Socket.SOCK.sock_type)
	  -> (('a, 'b) Socket.sock * ('a, 'b) Socket.sock)

  (* create sockets using the specified protocol *)
    val socket' : (Socket.AF.addr_family * Socket.SOCK.sock_type * int)
	  -> ('a, 'b) Socket.sock
    val socketPair' : (Socket.AF.addr_family * Socket.SOCK.sock_type * int)
	  -> (('a, 'b) Socket.sock * ('a, 'b) Socket.sock)

  end

(*
 * $Log: generic-sock-sig.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:41  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.1.1.1  1997/01/14 01:38:23  george
 *   Version 109.24
 *
 *)
