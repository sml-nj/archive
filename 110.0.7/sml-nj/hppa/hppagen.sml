(* hppagen.sml
 *
 * COPYRIGHT (c) 1996 Bell Laboratories.
 *
 *)

structure HppaMC = 
  CPScodeGenerator(
    structure HppaGen = HppaCG(structure Emitter=HppaMCEmitter)
    structure Gen=HppaGen.MLTreeGen
    fun collect() = (HppaGen.finish(); CodeString.getCodeString()))



(*
 * $Log: hppagen.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:46  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.1.1.1  1997/01/14 01:38:38  george
 *   Version 109.24
 *
 *)
