(* Copyright 1989 by      Department of Computer Science, 
 *                        The Technical University of Denmak
 *                        DK-2800 Lyngby 
 *
 * 17 Dec. 1991    Yngvi Skaalum Guttesen       (ysg@id.dth.dk)
 *)

structure MC386 : CODEGENERATOR = 
struct

  structure MachineCoder = MCode386(Jumps386)
  structure CMachine     = CM386(MachineCoder)
  structure MachineGen   = CPScomp(CMachine)

  fun generate lexp = (MachineGen.compile lexp; MachineCoder.finish())

end (* structure MC386 *)

structure AC386 : ASSEMBLER =
struct

  structure AssemCoder = ACode386()
  structure CMachine   = CM386(AssemCoder)
  structure AssemGen   = CPScomp(CMachine)

  fun generate(lexp,stream) = (Ass386.outfile := stream;
			       AssemGen.compile lexp)
end (* structure AC386 *)

structure Int386 = IntShare(structure Machm = MC386
			    val fileExtension = ".386"
			    structure D = BogusDbg
			   );

structure Comp386 = Batch(structure M=MC386 and A=AC386)

