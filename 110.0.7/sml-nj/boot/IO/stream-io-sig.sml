(* stream-io-sig.sml
 *
 * COPYRIGHT (c) 1995 AT&T Bell Laboratories.
 *
 *)

signature STREAM_IO =
  sig
    type vector
    type elem
    type reader
    type writer

    type instream
    type outstream

    type pos
    type in_pos
    type out_pos

    val input       : instream -> (vector * instream)
    val input1      : instream -> (elem * instream) option
    val inputN      : (instream * int) -> (vector * instream)
    val inputAll    : instream -> (vector * instream)
    val canInput    : (instream * int) -> int option
    val closeIn     : instream -> unit
    val endOfStream : instream -> bool
    val mkInstream  : (reader * vector option) -> instream
    val getReader   : instream -> (reader * vector)
    val getPosIn    : instream -> in_pos
    val setPosIn    : in_pos -> instream
    val filePosIn   : in_pos -> pos

    val output        : (outstream * vector) -> unit
    val output1       : (outstream * elem) -> unit
    val flushOut      : outstream -> unit
    val closeOut      : outstream -> unit
    val setBufferMode : (outstream * IO.buffer_mode) -> unit
    val getBufferMode : outstream -> IO.buffer_mode
    val mkOutstream   : (writer * IO.buffer_mode) -> outstream
    val getWriter     : outstream -> (writer * IO.buffer_mode)
    val getPosOut     : outstream -> out_pos
    val setPosOut     : out_pos -> unit
    val filePosOut    : out_pos -> pos

  end

(*
 * $Log: stream-io-sig.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:39  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.1.1.1  1997/01/14 01:38:19  george
 *   Version 109.24
 *
 *)
