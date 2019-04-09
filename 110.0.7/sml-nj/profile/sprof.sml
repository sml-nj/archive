(* COPYRIGHT (c) 1996 Bell Laboratories *)
(* sprof.sml *)

signature SPROF =
sig
  val instrumDec : StaticEnv.staticEnv * ElabUtil.compInfo ->
                     Source.inputSource -> Absyn.dec -> Absyn.dec

end (* signature SPROF *)


structure SProf :> SPROF =
struct

local structure SP = SymPath
      structure V = VarCon
      structure M  = Modules
      structure B  = Bindings
      structure P = PrimOp
      open Lambda Absyn VarCon Types BasicTypes
in 

(* 
 * WARNING: THE MAIN CODE IS CURRENTLY TURNED OFF; 
 *     we will merge in Chesakov's SProf in the future (ZHONG).
 *)

fun instrumDec (coreEnv, compInfo) source absyn = absyn

(* 

infix -->
val xsym = Symbol.varSymbol "x"

fun instrumDec coreEnv source absyn =
 if not(!SMLofNJ.Internals.ProfControl.sprofiling) then absyn
 else let 

val namelist : string list ref = ref nil
val namecount = ref 0

val alpha = IBOUND 0

val entervar as VALvar{typ=entertyp,...} = 
        mkVALvar(Symbol.varSymbol "enter", LVAR(LambdaVar.mkLvar()))
val _ = entertyp := POLYty{sign=[false],
			   tyfun = TYFUN{arity=1,
					 body=tupleTy[alpha,intTy] --> alpha}}


val enterexp = VARexp(ref entervar, [])

fun clean names = names
val err = ErrorMsg.impossible

fun enter((line_a,line_b),names,exp) = 
   let fun dot (a,[z]) = Symbol.name z :: a
	 | dot (a,x::rest) = dot("." :: Symbol.name x :: a, rest)
	 | dot _ = err "no path in instrexp"
       val (fname,lineno_a,charpos_a) = Source.filepos source line_a
       val (_,lineno_b,charpos_b) = Source.filepos source line_b
       val position = [fname,":",Int.toString lineno_a,".",
		       Int.toString charpos_a,"-", Int.toString lineno_b, ".",
		       Int.toString charpos_b,":"]
       val name =  concat (position @ dot (["\n"], names))
       val index = !namecount
    in namecount := index + 1;
       namelist := name :: !namelist;
       APPexp(enterexp,
	      ElabUtil.TUPLEexp[exp, INTexp (Int.toString index, intTy)])
   end		    

fun instrdec (line, names, VALdec vbl) =
    let fun instrvb (vb as VB{pat=VARpat(VALvar{access=PRIMOP _,...}),...}) =vb
	  | instrvb (vb as VB{pat=CONSTRAINTpat
	              (VARpat (VALvar{access=PRIMOP _,...}),_),...}) = vb
	  | instrvb (VB{pat as VARpat(VALvar{path=SP.SPATH[n],...}),
			exp,tyvars,boundtvs}) =
	      VB{pat=pat,
		 exp=instrexp(line, n::clean names) exp,
		 tyvars=tyvars, boundtvs=boundtvs}
	  | instrvb (VB{pat as CONSTRAINTpat(VARpat(VALvar{path=SP.SPATH[n],...}),_),
			exp,tyvars,boundtvs}) =
	      VB{pat=pat,
		 exp=instrexp(line, n::clean names) exp,
		 tyvars=tyvars, boundtvs=boundtvs}
	  | instrvb (VB{pat,exp,tyvars,boundtvs}) =
		    VB{pat=pat, exp=instrexp (line,names) exp, tyvars=tyvars,
		       boundtvs=boundtvs}
     in VALdec (map instrvb vbl)
    end
  
  | instrdec (line, names, VALRECdec rvbl) =
     let fun instrrvb (RVB{var as VALvar{path=SP.SPATH[n],...},
			   exp,resultty,tyvars,boundtvs}) =
	       RVB{var=var,
		   exp=instrexp (line, n::clean names) exp, 
		   resultty=resultty, tyvars=tyvars, boundtvs=boundtvs}
	   | instrrvb _ = err "VALRECdec in SProf.instrdec"
      in VALRECdec(map instrrvb rvbl)
     end
  | instrdec(line, names, ABSTYPEdec {abstycs,withtycs,body}) = 
      ABSTYPEdec {abstycs=abstycs,withtycs=withtycs, 
		  body=instrdec(line, names, body)}
  | instrdec(line,names, STRdec strbl) = 
             STRdec (map (fn strb => instrstrb(line,names,strb)) strbl)
  | instrdec(line,names, ABSdec strbl) = 
             ABSdec (map (fn strb => instrstrb(line,names,strb)) strbl)
  | instrdec(line,names, FCTdec fctbl) = 
             FCTdec (map (fn fctb => instrfctb(line,names,fctb)) fctbl)
  | instrdec(line,names, LOCALdec(localdec,visibledec)) =
	LOCALdec(instrdec (line,names,localdec), 
		 instrdec (line,names,visibledec))
  | instrdec(line,names, SEQdec decl) = 
        SEQdec (map (fn dec => instrdec(line,names,dec)) decl)
  | instrdec(line,names, MARKdec(dec,region)) = 
        MARKdec(instrdec (region,names,dec), region)
  | instrdec(line,names, other) = other

and (* instrstrexp(line, names, STRUCTstr {body,locations,str}) =
      STRUCTstr{body = (map (fn dec => instrdec(line,names,dec)) body),
                locations=locations,str=str}
  | *) instrstrexp(line, names, APPstr {oper,arg,argtycs,res,restycs}) = 
      APPstr{oper=oper, arg=instrstrexp(line,names,arg),
	     argtycs=argtycs, res=res, restycs=restycs}
  | instrstrexp(line, names, VARstr x) = VARstr x
  | instrstrexp(line, names, LETstr(d,body)) = 
		LETstr(instrdec(line,names,d), instrstrexp(line,names,body))
  | instrstrexp(line, names,MARKstr(body,region)) = 
             MARKstr(instrstrexp(region,names,body),region)

and instrstrb (line, names, STRB{name, str, def}) = 
        STRB{str=str, def=instrstrexp(line, name::names, def), name=name}

and instrfctb (line, names,
               FCTB{fct, name, def=FCTfct{param, def=d, argtycs, 
                                          fct=f, restycs}}) =
      FCTB{fct=fct, name=name,
	   def=FCTfct{param=param, def=instrstrexp(line, name::names, d),
		      fct=f, restycs=restycs, argtycs=argtycs}}
  | instrfctb (line, names, fctb) = fctb

and instrexp(line,names) =
 let fun rule(RULE(p,e)) = RULE(p, iexp e)
     and iexp (RECORDexp(l as _::_)) =
          let fun field(lab,exp) = (lab, iexp exp)
           in enter(line,Symbol.varSymbol(Int.toString(length l))::names,
		       RECORDexp(map field l))
          end
       | iexp (VECTORexp(l,t)) = VECTORexp((map iexp l),t)
       | iexp (SEQexp l) = SEQexp(map iexp l)
       | iexp (APPexp(f,a)) = APPexp(iexp f, iexp a)
       | iexp (CONSTRAINTexp(e,t)) = CONSTRAINTexp(iexp e, t)
       | iexp (HANDLEexp (e, HANDLER(FNexp(l,t)))) = 
	   HANDLEexp(iexp e, HANDLER(FNexp(map rule l, t)))
       | iexp (HANDLEexp (e, HANDLER h)) = HANDLEexp(iexp e, HANDLER(iexp h))
       | iexp (RAISEexp(e,t)) = RAISEexp(iexp e, t)
       | iexp (LETexp(d,e)) = LETexp(instrdec(line,names,d), iexp e)
       | iexp (CASEexp(e,l,b)) = CASEexp(iexp e, map rule l, b)
       | iexp (FNexp(l,t)) = enter(line,names,(FNexp(map rule l, t)))
       | iexp (MARKexp(e,region)) = MARKexp(instrexp(region,names) e, region)
       | iexp (e as CONexp(DATACON{rep,...},_)) =
           (case rep
	      of (UNTAGGED | TAGGED _ | REF | EXNFUN _) => (*ZHONG?*)
		  etaexpand e
	       | _ => e)
       | iexp e = e 

     and etaexpand(e as CONexp(_,t)) = 
	 let val v = VALvar{access=LVAR(LambdaVar.mkLvar()), 
                            path=SP.SPATH [xsym], 
	                    typ=ref Types.UNDEFty}
	  in FNexp([RULE(VARpat v, 
			 enter(line,names,APPexp(e,VARexp(ref v, []))))],
		   Types.UNDEFty)
	 end
       | etaexpand _ = err "etaexpand in sprof.sml"
  in iexp
 end


val derefop = VALvar{path = SP.SPATH [Symbol.varSymbol "!"],
		     access = PRIMOP P.DEREF,
		     typ = ref(POLYty{sign=[false],
				      tyfun = TYFUN{arity=1,
						    body=
						      CONty(refTycon,[alpha]) 
						      --> alpha}})}

val registerTy =  
    POLYty{sign=[false],
	   tyfun = TYFUN{arity=1,
			 body= CONty(refTycon,[stringTy -->
					       (tupleTy[alpha,intTy] 
						--> alpha)])}}

val V.VAL registerVar = Lookup.lookVal
    (coreEnv,
     SP.SPATH [Symbol.strSymbol "Core", Symbol.varSymbol "profile_sregister"],
     fn _ => fn s => fn _ => err "222 in sprof")

val absyn' =instrdec((0,0),nil,absyn) 

in 
   LOCALdec(VALdec[VB{pat=VARpat entervar,
		      exp=APPexp(APPexp(VARexp(ref derefop,[]),
					VARexp(ref(registerVar),[])),
				 STRINGexp(concat(rev(!namelist)))),
		      tyvars=ref nil,
		      boundtvs=[]}], (* ZHONG? *)
	     absyn')

end (* function instrumDec *)

*)

end (* local *)
end (* structure SProf *)


(*
 * $Log: sprof.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:47  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.3  1997/06/30 19:37:43  jhr
 *   Removed System structure; added Unsafe structure.
 *
 * Revision 1.2  1997/01/31  20:40:06  jhr
 * Replaced uses of "abstraction" with opaque signature matching.
 *
 * Revision 1.1.1.1  1997/01/14  01:38:44  george
 *   Version 109.24
 *
 *)
