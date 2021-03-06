(* ra-params.sig --- machine parameter required for register allocation.
 *
 * Copyright 1996 AT&T Bell Laboratories 
 *
 *)

signature RA_ARCH_PARAMS = sig

  structure Liveness : LIVENESS
  structure InsnProps : INSN_PROPERTIES
  structure AsmEmitter : EMITTER_NEW
  structure I : INSTRUCTIONS

    (* all modules work on the same instruction type *)
    sharing Liveness.F.I = InsnProps.I = AsmEmitter.I = I

  val firstPseudoR : int
  val maxPseudoR : unit -> int
  val numRegs : unit -> int
  val regSet : I.C.cellset -> int list
  val defUse : I.instruction -> (int list * int list)
end



signature RA_USER_PARAMS = sig

  structure I : INSTRUCTIONS

  val nFreeRegs : int
  val dedicated : int list	(* dedicated registers *)
  val getreg : {pref: int list, proh: int list} -> int
  val copyInstr : int list * int list -> I.instruction

  val spill : 
    {instr : I.instruction,	(* instruction where spill is to occur *)
     reg: int			(* register to spill *)
     } 
       ->
     {code: I.instruction list,	(* spill or reload code *)
      proh: int list,		(* regs prohibited from future spilling *)
      instr: I.instruction option}	(* possibly changed instruction *)

  val reload : 
     {instr : I.instruction,	(* instruction where spill is to occur *)
      reg: int			(* register to spill *)
     } 
       -> 
     {code: I.instruction list,	(* spill or reload code *)
      proh: int list}		(* regs prohibited from future spilling *)

end



signature RA = sig
  structure F : FLOWGRAPH
  datatype mode = REGISTER_ALLOCATION | COPY_PROPAGATION

  val ra: mode -> F.cluster -> F.cluster
end 


(*
 * $Log: ra-params.sig,v $
 * Revision 1.1.1.1  1999/12/03 19:59:35  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.3  1997/07/17 12:30:07  george
 *   The regmap is now represented as an int map rather than using arrays.
 *
# Revision 1.2  1997/07/02  13:22:52  george
#   Added a mode to do either copy-propagation alone or copy-propagation
#   and register allocation.
#
# Revision 1.1.1.1  1997/04/19  18:14:21  george
#   Version 109.27
#
 *)
