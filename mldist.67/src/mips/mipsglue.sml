(* For assembly-language output, we slip in first and tell it what outstream 
     to use. *)

structure MipsAC : ASSEMBLER = struct
    structure MCN = MipsCoder(Emitters.MipsAsm)
    structure Gen = CPScomp(MipsCM(MCN))
    fun generate (lexp, stream) = (
	Emitters.asmstream := stream;
	Gen.compile lexp;
	MCN.codestats stream;
	Emitters.address := 0;
	MCN.codegen ();
	())
end

structure MipsCodeStats : ASSEMBLER = struct
    structure MCN = MipsCoder(Emitters.MipsAsm)
    structure Gen = CPScomp(MipsCM(MCN))
    fun generate (lexp, stream) = (
	Emitters.asmstream := stream;
	Gen.compile lexp;
	MCN.codestats stream;
	())
end

(* Mips machines come in two byte-orders, so we need two of                 *)
(* every machinelike thing.                                                 *)

structure MipsMCBig : CODEGENERATOR = struct
    structure Coder = MipsCoder(Emitters.BigEndian)
    structure Gen = CPScomp(MipsCM(Coder))
    fun generate lexp = (
	Gen.compile lexp;
	Coder.codegen ();
	Emitters.emitted_string ()
	)
end

structure MipsMCLittle : CODEGENERATOR = struct
    structure Coder = MipsCoder(Emitters.LittleEndian)
    structure Gen = CPScomp(MipsCM(Coder))
    fun generate lexp = (
	Gen.compile lexp;
	Coder.codegen ();
	Emitters.emitted_string ()
	)
end


structure CompMipsLittle = Batch(structure M=MipsMCLittle and A=MipsAC)
structure IntMipsLittle = IntShare(structure Machm = MipsMCLittle
				   val fileExtension = ".mipsel"
			 	   structure D = BogusDebug)
structure IntMipsLittleD = IntShare(structure Machm = MipsMCLittle
				   val fileExtension = ".mipsel"
			 	   structure D = RealDebug)

structure CompMipsBig = Batch(structure M=MipsMCBig and A=MipsAC)
structure IntMipsBig = IntShare(structure Machm = MipsMCBig
				   val fileExtension = ".mipseb"
			 	   structure D = BogusDebug)
structure IntMipsBigD = IntShare(structure Machm = MipsMCBig
				   val fileExtension = ".mipseb"
			 	   structure D = RealDebug)

structure CompMipsStats = Batch(structure M=MipsMCLittle and A=MipsCodeStats)
