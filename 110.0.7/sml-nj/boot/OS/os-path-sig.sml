(* os-path-sig.sml
 *
 * COPYRIGHT (c) 1995 AT&T Bell Laboratories.
 *
 * The generic interface to syntactic pathname manipulation.
 *
 *)

signature OS_PATH =
  sig

    exception Path

    val parentArc  : string
    val currentArc : string

    val validVolume : {isAbs : bool, vol : string} -> bool

    val fromString : string -> {isAbs : bool, vol : string, arcs : string list}
    val toString   : {isAbs : bool, vol : string, arcs : string list} -> string

    val getVolume   : string -> string
    val getParent   : string -> string

    val splitDirFile : string -> {dir : string, file : string}
    val joinDirFile  : {dir : string, file : string} -> string
    val dir	     : string -> string
    val file	     : string -> string
    
    val splitBaseExt : string -> {base : string, ext : string option}
    val joinBaseExt  : {base : string, ext : string option} -> string
    val base	     : string -> string    
    val ext	     : string -> string option

    val mkCanonical : string -> string
    val isCanonical : string -> bool

    val mkAbsolute  : (string * string) -> string
    val mkRelative  : (string * string) -> string
    val isAbsolute  : string -> bool
    val isRelative  : string -> bool

    val isRoot      : string -> bool

    val concat      : (string * string) -> string

  end; (* OS_PATH *)

(*
 * $Log: os-path-sig.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:40  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.1.1.1  1997/01/14 01:38:21  george
 *   Version 109.24
 *
 *)
