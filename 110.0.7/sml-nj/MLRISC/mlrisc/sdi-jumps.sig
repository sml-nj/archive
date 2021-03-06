(* sdi-jumps.sig --- specification of target information to resolve jumps. 
 *
 * COPYRIGHT (c) 1996 Bell Laboratories.
 *
 *)

signature SDI_JUMPS = sig
  structure I : INSTRUCTIONS
  structure C : CELLS
    sharing I.C = C

  val branchDelayedArch : bool

  val isSdi : I.instruction -> bool
  val minSize : I.instruction -> int
  val maxSize : I.instruction -> int
      (* minSize and maxSize are not restricted to SDIs but 
       * instructions that may require NOPs after them, etc. 
       *)

  val sdiSize : I.instruction * int Intmap.intmap
			      * (Label.label -> int) * int -> int
      (* sdiSize(instr, regmaps, labMap, loc) -- return the size of
       * instr at location loc, assuming an assignment of labels
       * given by labMap.
       *)

  val expand	: I.instruction * int -> I.instruction list
      (* expand(instr,size) - expands sdi instruction instr,
       *  into size bytes.
       *)

end


(*
 * $Log: sdi-jumps.sig,v $
 * Revision 1.1.1.1  1999/12/03 19:59:35  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.2  1997/07/17 12:33:01  george
 *   The regmap is now represented as an int map rather than using arrays.
 *
# Revision 1.1.1.1  1997/04/19  18:14:21  george
#   Version 109.27
#
 *)
