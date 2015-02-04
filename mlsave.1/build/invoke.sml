(* invoke.sml *)

functor invoke(machm : machineCode, macha : assemblyCode) =
struct

  local open intmap
	val m : string intmap = new()
   in val enterName = add m
      val lookupName = map m
      val lookupName = fn v => lookupName v 
            handlex intmap => let val s = Access.lvarName v
			      in  ErrorMsg.Complain ("Bad free variable: "
						 ^ Access.lvarName v);
				  s
			     end
  end

 local open Access Basics Lambda (* can duplicate bind  bug by removing *)
  in				  (* these lines *)

   fun freevars e =
      let val T = intset.new()
	  val set = intset.add T
	  val unset = intset.rem T
	  val done = intset.mem T
	  val free : int list ref = ref nil
	  fun root [v] = v | root (_::p) = root p
	  val rec mak =
	     fn VAR w => if done w then () else (set w; free := w :: !free)
	      | FN (w,b) => (set w; mak b; unset w)
	      | FIX (vl,el,b) => (app set vl; app mak (b::el); app unset vl)
	      | APP (f,a) => (mak f; mak a)
	      | SWITCH(e,l,d) => (mak e;
				  app (fn (DATAcon(DATACON{rep=ref(VARIABLE(Access.PATH p)),...}),e) =>
				            (mak(VAR(root p)); mak e)
					| (c,e) => mak e)
				      l;
				  case d of NONE => () | SOME a => mak a)
	      | RECORD l => app mak l
	      | SELECT (i,e) => mak e
	      | HANDLE (a,h) => (mak a; mak h)
	      | RAISE e => mak e
	      | INT _ => ()
	      | REAL _ => ()
	      | STRING _ => ()
       in set 0; mak e; !free
      end
   
   fun closestr e =
      let val fv = freevars e
	  val names = map lookupName fv
       in FN(mkLvar(),RECORD
	  [fold (fn (v,f) =>
		let val w = mkLvar()
		 in FN(w,APP(FN(v,APP(f,SELECT(1,(VAR w)))),SELECT(0,(VAR w))))
		end) fv (FN(mkLvar(),e)),
	   fold (fn (s,f) => RECORD[STRING 
( print s; print " "; s )  (* should be just   s   *)
 , f])
		names (RECORD nil)])
      end

    fun closetop e =
	 let val looker = Access.mkLvar()
	     val fv = freevars e
	  in FN(looker,
		fold (fn (v,f) =>
			 APP(FN(v,f),APP(VAR looker, INT v)))
		     fv e)
         end

   end (* local *)

val _ = print("invoke0\n")
   structure machine = codegen(machm.M)
val _ = print("invoke0\n")
   structure amachine = codegen(macha.M)
val _ = print("invoke0\n")

   val absyn = ref (Absyn.SEQdec [])
   val lambda = ref (Lambda.RECORD [])
   val vars = ref (nil : int list)
   fun p () = (MCprint.printLexp(!lambda); print "\n"; ())
   val saveLambda = ref false


   exceptionx stop

   fun process (fname, gencode) =
       let val file = open_in fname
        in Lex.openSource(file, fname);
	  (while true do 
	   ((ErrorMsg.AnyErrors := false;
	     if !saveLambda then () else lambda := Lambda.RECORD [];
	     absyn := Parse.tdec();
	     print "parsed\n";
	     if !ErrorMsg.AnyErrors then raisex stop else ();
   	     let open Access Basics BareAbsyn
		 val (name,lvar) = case !absyn
	            of STRdec(STRB{strvar=STRvar{name,access=LVAR v,...},...})
			     => (Symbol.Name name, v)
	             | FCTdec(FCTB{fctvar=FCTvar{name,access=LVAR v,...},...})
			     => (Symbol.Name name, v)
	      in lambda := translate.topdec (!absyn); print "translated\n";
	         if !ErrorMsg.AnyErrors then raisex stop else ();
	         absyn := Absyn.SEQdec [];
	         lambda := closestr (!lambda); print("closed\n");
	         lambda := Opt.reduce (!lambda); print("reduced\n");
	         if !CGoptions.hoist
		    then (lambda := Opt.hoist(!lambda); print "hoisted\n";())
		    else ();
	         if !ErrorMsg.AnyErrors then raisex stop else ();
	         enterName(lvar, name);
		 gencode(!lambda, name)
	     end)
	    handlex stop => ()
	    ))
          handlex Parse.EOF => () || ErrorMsg.Syntax => ();
	  print("[closing "^ fname ^ "]\n");
	  if !saveLambda then () else lambda := Lambda.RECORD [];
	  close_in file
	end

   fun load fname =
       let val file = open_in fname
        in Lex.openSource(file, fname);
	 (while true do 
   	     let open Access Basics BareAbsyn
		 val _ = absyn := Parse.tdec()
		 val (name,lvar) = case !absyn
	            of STRdec(STRB{strvar=STRvar{name,access=LVAR v,...},...})
			     => (Symbol.Name name, v)
	             | FCTdec(FCTB{fctvar=FCTvar{name,access=LVAR v,...},...})
			     => (Symbol.Name name, v)
	      in enterName(lvar, name)
	     end)
          handlex Parse.EOF => () || ErrorMsg.Syntax => ();
	  print("[closing "^ fname ^ "]\n");
	  close_in file
	end

   fun assemble(fname : string) =
	 process(fname,
	           (fn (lexp,s) => 
		    let val outfile = open_out( s ^ ".s")
		     in system("chmod +rw " ^ s ^ ".s");
			macha.outfile := outfile;
		        amachine.generate lexp
		        handlex amachine.notfound with v
			 => (MCprint.printLexp (Lambda.VAR v);
			     raisex amachine.notfound with v);
			close_out outfile
		    end))

   fun check(fname : string) =
	 process(fname, (fn (lexp,s) => ()))

   fun compile(fname : string) =
	 process(fname,
	           (fn (lexp,s) => 
		    let val (size,f) = (machine.generate lexp;
			                machm.assemble())
			val outfile = open_out( s ^ ".mo")
			val _ = system("chmod +rw " ^ s ^ ".mo")
		        fun writebyte i = output(outfile,chr(i))
			fun writeint i = (writebyte(i div 16777216);
					  writebyte((i div 65536) mod 256);
					  writebyte((i div 256) mod 256);
					  writebyte(i mod 256))
		     in writeint size;
			f writebyte;
		        close_out outfile
		    end))

  local open Access Basics
val _ = print("invoke1\n")
   in
   val _ = 
     let val DIRECT{table,context,...} = Prim.PrimTypes
      in Env.initBase((([0],context),table),(([0],context),table))
     end
val _ = print("invoke2\n")
   val PTsym = SymbolTable.StringToSymbol "PrimTypes"
   val PTvar = STRvar{name=PTsym,access=LVAR(0),
	 	      binding=Prim.PrimTypes,sign=NONE}
   val ILPsym = SymbolTable.StringToSymbol "InLinePrim"
   val ILPvar = STRvar{name=ILPsym,access=LVAR(0),
	 	       binding=Prim.InLinePrim,sign=NONE}
   fun reset() =
       (Env.reset();
        Env.add(PTsym,STRbind(PTvar));
        Env.add(ILPsym,STRbind(ILPvar));
	EnvAccess.reset();
	Typecheck.reset();
	Parse.reset())

   val _ = reset()

    fun resetBase (s1,s2) =
    let val STRvar{binding=DIRECT{table=t1,context=c1,...},access=PATH p1,...}
              = EnvAccess.lookSTR(SymbolTable.StringToSymbol s1)
        val STRvar{binding=DIRECT{table=t2,context=c2,...},access=PATH p2,...}
              = EnvAccess.lookSTR(SymbolTable.StringToSymbol s2)
     in Env.initBase (((p1,c1),t1),((p2,c2),t2))
    end

    fun bootEnv () =
    (reset();
     compile "boot/pervsig.sml";
     compile "boot/perv.sml";
     compile "boot/assembly.sml";
     compile "boot/overload.sml";
     resetBase("Initial","Overloads"))

    fun bootEnv1 () =
    (reset();
     compile "boot/pervsig.sml";
     load "boot/perv.sml";
     load "boot/assembly.sml";
     load "boot/overload.sml";
     resetBase("Initial","Overloads"))

  end

   fun root [v] = v | root (a::p) = root p;

   fun compileIn() =
     let val _ = (bootEnv1(); print "Go for it\n")
	 open Access Basics
	 val T = intmap.new() : Boot.Structure intmap.intmap
	 val set = intmap.add T
	 val lookup = intmap.map T
	 val VALvar{access=PATH p,...} = 
		EnvAccess.lookVARinBase (SymbolTable.StringToSymbol "std_in")
	 val _ = set(root p, !Boot.pstruct);
	 fun use1 () =
	  (while true do 
	   ((ErrorMsg.AnyErrors := false;
	     if (!ErrorMsg.FileName)="std_in" andalso is_term_in std_in
		then (output(std_out,"-> "); flush_out std_out) else ();
	     absyn := Parse.interdec();
	     print "parsed\n";
	     PrintAbsyn.printDec (!absyn);
	     if !ErrorMsg.AnyErrors then raisex stop else ();
	     vars := translate.getvars (!absyn);
	     lambda := translate.makedec (!absyn)
				 (Lambda.RECORD(map Lambda.VAR (!vars)));
	     print "translated\n";
	     if !ErrorMsg.AnyErrors then raisex stop else ();
	     lambda := closetop (!lambda); print("closed\n");
	     lambda := Opt.reduce (!lambda); print("reduced\n");
	     if !ErrorMsg.AnyErrors then raisex stop else ();
   	     let open Access Basics BareAbsyn
		 val (size,f) = (machine.generate (!lambda); machm.assemble())
		 open Byte_array
		 val a = create(size,0)
		 val pos = ref 0
	         fun writebyte i = (store(a,!pos,i); inc pos)
		 val result = (f writebyte;
print "about to boot\n";
			       Boot.boot1 a lookup)
		 fun set1 (i,v::r) = (set(v,result sub i); set1 (i+1,r))
		   | set1 (_,nil) = ()
	      in set1(0,!vars);
		 PrintDec.printDec lookup (!absyn);
		 flush_out std_out;
	         absyn := SEQdec nil
	     end)
	    handle e_stop() => raisex ErrorMsg.Syntax
		  | Parse.e_EOF() => raisex Parse.EOF
		  | f => (print ("uncaught exception "^  exn_name f ^"\n");
			  raisex ErrorMsg.Syntax)))
          handlex Parse.EOF => ()
     fun use2 (fname::r) = 
	let val _ = print("[opening "^fname^"]\n")
	    val (prev,new) = Lex.openSource(open_in fname, fname)
         in use1() 
	    handlex ErrorMsg.Syntax => 
		    (Lex.closeSource new; Lex.resumeSource prev;
		     raisex ErrorMsg.Syntax);
	    Lex.closeSource new;
	    Lex.resumeSource prev;
	    use2 r
	end
       | use2 nil = ()
     fun use3() =  use1() handlex ErrorMsg.Syntax => use3()
    in Boot.useref := use2;
       Lex.openSource(std_in,"std_in");
       use3()
   end;



end (* structure invoke *)
