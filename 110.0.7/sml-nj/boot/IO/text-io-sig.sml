(* text-io-sig.sml
 *
 * COPYRIGHT (c) 1995 AT&T Bell Laboratories.
 *
 *)

signature TEXT_IO =
  sig

  (* include IMPERATIVE_IO *)
    type vector = string
    type elem = char

    type instream
    type outstream

    val input    : instream -> vector
    val input1   : instream -> elem option
    val inputN   : (instream * int) -> vector
    val inputAll : instream -> vector
    val canInput : (instream * int) -> int option
    val lookahead : instream -> elem option
    val closeIn : instream -> unit
    val endOfStream : instream -> bool

    val output   : (outstream * vector) -> unit
    val output1  : (outstream * elem) -> unit
    val flushOut : outstream -> unit
    val closeOut : outstream -> unit

    structure StreamIO : TEXT_STREAM_IO
      where type vector = string
      and type elem = char

    val getPosIn    : instream -> StreamIO.in_pos
    val setPosIn    : (instream * StreamIO.in_pos) -> unit
    val mkInstream  : StreamIO.instream -> instream
    val getInstream : instream -> StreamIO.instream
    val setInstream : (instream * StreamIO.instream) -> unit

    val getPosOut    : outstream -> StreamIO.out_pos
    val setPosOut    : (outstream * StreamIO.out_pos) -> unit
    val mkOutstream  : StreamIO.outstream -> outstream
    val getOutstream : outstream -> StreamIO.outstream
    val setOutstream : (outstream * StreamIO.outstream) -> unit

    val inputLine    : instream -> string
    val outputSubstr : (outstream * substring) -> unit

    val openIn     : string -> instream
    val openString : string -> instream
    val openOut    : string -> outstream
    val openAppend : string -> outstream

    val stdIn  : instream
    val stdOut : outstream
    val stdErr : outstream

    val print : string -> unit

    val scanStream :
	  ((elem, StreamIO.instream) StringCvt.reader
	    -> ('a, StreamIO.instream) StringCvt.reader
	  ) -> instream -> 'a option

  end;

(*
 * $Log: text-io-sig.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:39  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.3  1997/11/18 17:19:45  jhr
 *   Added missing scanStream function.
 *
 * Revision 1.2  1997/05/20  12:13:50  dbm
 *   SML '97 sharing, where structure.
 *
 * Revision 1.1.1.1  1997/01/14  01:38:19  george
 *   Version 109.24
 *
 *)
