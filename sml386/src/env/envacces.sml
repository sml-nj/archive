(* Copyright 1989 by AT&T Bell Laboratories *)
structure EnvAcc : ENVACCESS = struct
(* lookup and binding functions *)

structure Access = Access
structure Basics = Basics
structure Env = Env

open ErrorMsg PrtUtil Access Basics Basics.Symbol BasicTyp TypesUtl Env
     NmSpace

val debugBind = System.Control.debugBind

fun openStructureVar(STRvar{access=PATH p,binding,...}) =
    (case binding
      of STRstr{table,env,...} => openOld({path=p,strenv=env},table)
       | INDstr _ => impossible "EnvAcc.openStructureVar -- INDstr arg"
       | SHRstr _ => impossible "EnvAcc.openStructureVar -- SHRstr arg"
       | NULLstr => impossible "EnvAcc.openStructureVar -- NULLstr arg")
  | openStructureVar _ = impossible "EnvAcc.openStructureVar -- bad access value"

val bogusID = Symbol.symbol "bogus"

val bogusStrStamp = Stampset.newStamp(Stampset.fixedStrStamps)

local val b = STRstr{stamp=bogusStrStamp, sign=0, table=newTable(), env=DIR,
		     kind=STRkind{path=[bogusID]}}
 in val bogusSTR = STRvar{name=[bogusID], access=PATH[0], binding=b}
    val bogusSTR' = STRvar{name=[bogusID], access=SLOT 0, binding=b}
end

(* type constructors *)

val bogusTyc = DEFtyc{path=[bogusID],tyfun=TYFUN{arity=0,body=ERRORty}}

fun lookTYCinTable(table,id) =
    let val TYCbind tyc = IntStrMp.map table (tycKey id)
     in tyc
    end

fun lookTYCinStr(STRstr{table,env,stamp,...}: Structure, id: symbol,_,_,
		  err : string->unit) : tycon =
    ((case lookTYCinTable(table,id)
	of INDtyc i =>
	     (case env
	       of REL{s,t} => t sub i
	        | DIR => impossible "EnvAcc.lookTYCinStr 1")
	 | SHRtyc p => getEpathTyc(p,env)
	 | tyc => tyc)
     handle UnboundTable => 
	(if stamp=bogusStrStamp then ()
	 else err("unbound type in structure: " ^ Symbol.name id);
	 bogusTyc))
  | lookTYCinStr _ = impossible "EnvAcc.lookTYCinStr 2"

fun lookTYC' look (id:symbol) =
    case look(tycKey(id))
      of (TYCbind(INDtyc i), {strenv=REL{s,t},path}) =>
	    (t sub i  handle Subscript => impossible "EnvAcc.lookTYC' 1")
       | (TYCbind(SHRtyc p), {strenv,path}) =>
	    (getEpathTyc(p,strenv) handle Subscript => 
				       impossible "EnvAcc.lookTYC' 2")
       | (TYCbind tyc, _) => tyc
       | _ => impossible "EnvAcc.lookTYC' 3"

val lookTYC = lookTYC' look
val lookTYClocal = lookTYC' lookStrLocal

(* addzeros also defined in Parse *)
fun addzeros(0,l) = l
  | addzeros(n,l) = addzeros(n-1,0::l)

fun bindTYC(id: symbol, tc: tycon) =
    let val binding = TYCbind tc 
     in add(tycIndex id, name id, binding); binding
    end


(* tycon lookup with arity checking *)

fun checkArity(tycon, arity,err) =
    if tyconArity(tycon) <> arity
    then err("type constructor "^(Symbol.name(tycName(tycon)))^
	          " has wrong number of arguments: "^makestring arity)
    else ()

fun lookArTYC(id,arity,err) =
    let val tyc = lookTYC id
     in checkArity(tyc,arity,err);
        tyc
    end
    handle Unbound => 
      (err("unbound type constructor: " ^ Symbol.name id);
       bogusTyc)

fun lookArTYCinSig (depth: int) (id: symbol, arity: int, err) =
    (case look(tycKey id)
      of (TYCbind(INDtyc i), {strenv=REL{s,t},path=h::r}) =>
	   if h >= 0
	   then let val tyc = t sub i
		 in checkArity(tyc,arity,err);
		    tyc
		end
	   else (checkArity(t sub i, arity,err);
		 RELtyc(addzeros(depth+h,r@[i])))
       | (TYCbind(SHRtyc p), {strenv,path}) =>
	   let val tyc = getEpathTyc(p,strenv)
	    in checkArity(tyc,arity,err);
	       tyc
	   end
       | (TYCbind tyc, _) => (checkArity(tyc,arity,err); tyc)
       | _ => impossible "EnvAcc.lookTYCinSig")
    handle Unbound => 
      (err("unbound type constructor in signature: " ^ Symbol.name id);
       bogusTyc)

(* constructors *)

fun dconApplied(DATACON{name,const,typ,rep,sign},{path,strenv}:info) : datacon =
    DATACON{name = name, const = const, sign=sign,
            rep = (case rep
		     of VARIABLE(SLOT n) => VARIABLE(PATH(n::path))
		      | VARIABLE(LVAR v) => VARIABLE(PATH [v])
		      | _ => rep),  (* nonexception datacon *)
            typ = typeInContext(typ,strenv)}

fun lookCONinTable(table,id) = 
    case IntStrMp.map table (varKey(id))
      of CONbind c => c
       | _ => raise UnboundTable

fun lookCON' lookfn id =
    case lookfn(varKey(id))
      of (CONbind c,info) => dconApplied(c,info)
       | _ => raise Unbound

val lookCON = lookCON' look
val lookCONlocal = lookCON' lookStrLocal

val bogusCON = DATACON{name=bogusID,const=true,typ=ERRORty,
		       rep=UNDECIDED,sign=[]}

fun lookCONinStr(STRstr{table,env,stamp,...},id,ap,qid,err): datacon =
    (dconApplied(lookCONinTable(table,id),{path=ap,strenv=env})
     handle UnboundTable => 
	(if stamp=bogusStrStamp then ()
	 else err("unbound constructor in structure: " ^ Symbol.name id);
	 bogusCON))
  | lookCONinStr _ = impossible "EnvAcc.lookCONinStr"

fun bindCON (id: symbol, c: datacon) = 
    let val binding = CONbind c 
     in add(conIndex id, name id, binding); binding
    end

(* variables *)

fun varApplied(VALvar{access,name,typ}: var, {path, strenv}: info, qid) : var =
      VALvar{access =
	       (case access
		  of SLOT(n) => PATH(n::path)
		   | LVAR(n) => PATH([n])
		   | INLINE _ => access
		   | PATH _ => impossible "varApplied: access = PATH"),
	     typ = case path
		     of [] => typ
		      | _ => ref(typeInContext(!typ,strenv)),
	     name = qid}
  | varApplied(v, _, _) = v

fun lookVARinTable(table, id) =
    case IntStrMp.map table (varKey id)
      of VARbind v => v
       | _ => raise UnboundTable

fun lookVARCONinTable(table,id) = IntStrMp.map table (varKey id)

fun lookVARCONinStr(STRstr{table,env,stamp,...},id,ap,qid,err): binding =
    ((case lookVARCONinTable(table,id)
       of VARbind(var) => VARbind(varApplied(var,{path=ap,strenv=env},qid))
	| CONbind(dcon) => CONbind(dconApplied(dcon,{path=ap,strenv=env}))
	| _ => impossible "EnvAcc.lookVARCONinStr 1")
     handle UnboundTable =>
	(if stamp=bogusStrStamp then ()
	 else err("unbound variable or constructor in structure: "
		       ^ Symbol.name id);
	 CONbind bogusCON))
  | lookVARCONinStr(NULLstr,id,_,_,_) =
      (printSym id; print "\n"; impossible "EnvAcc.lookVARCONinStr 2")
  | lookVARCONinStr(_,id,_,_,_) =
      (printSym id; print "\n"; impossible "EnvAcc.lookVARCONinStr 3")

fun lookVARCON id = 
     case look(varKey id)
      of (VARbind v, info) => VARbind(varApplied(v,info,[id]))
       | (CONbind d, info) => CONbind(dconApplied(d,info))
       | _ => impossible "EnvAcc.lookVARCON"

fun lookVARCONlocal id = 
    case lookStrLocal(varKey id)
      of (VARbind v, info) => VARbind(varApplied(v,info,[id]))
       | (CONbind d, info) => CONbind(dconApplied(d,info))
       | _ => impossible "EnvAcc.lookVARCON"

fun bindVAR(id: symbol, v: var) = 
	let val binding = VARbind v
	 in add(varIndex id, name id, binding); binding
	end

(* exceptions *)

fun notInitialLowerCase string =
    (* string does NOT start with lower-case alpha *)
    let val firstchar = ordof(string,0)
     in firstchar < Ascii.lc_a orelse firstchar > Ascii.lc_z
    end

(* signatures *)

val bogusSIGStampsets = Stampset.newStampsets()
val bogusSIGbody = 
    STRstr{stamp=Stampset.newStamp(#strStamps bogusSIGStampsets),
           sign=Stampset.newStamp(Stampset.sigStamps),
           table=newTable(),
	   env=DIR,
	   kind=SIGkind{share={s=nil,t=nil},
		        bindings=nil,stamps=bogusSIGStampsets}}
val bogusSIG=SIGvar{name=bogusID,binding=bogusSIGbody}

fun lookSIG id = let val (SIGbind sign, _) = look(sigKey id) in sign end

fun bindSIG(id: symbol, s: signatureVar) = add(sigIndex id, name id, SIGbind s)

(* structures *)

fun strApplied(STRvar{name,access,binding},{path=ap,strenv},qid) =
    STRvar{name=qid,
	   binding=(case (binding,strenv)
		     of (INDstr i,REL{s,...}) => s sub i
		      | (SHRstr(i::r),REL{s,...}) => getEpath(r,s sub i)
		      | (STRstr _, _) => binding
		      | _ => impossible "strApplied: bad binding/env"),
	   access=(case access
		     of SLOT(n) => PATH(n::ap)
		      | LVAR(n) => PATH [n]
		      | _ => impossible "strApplied: access = PATH or INLINE")}

fun lookSTRinTable(table, id) = 
    let val STRbind strvar = IntStrMp.map table (strKey id) in strvar end

fun lookSTR0 id = 
    let val (STRbind str, info) = look(strKey id)
     in (str,info)
    end

fun lookSTR' look id =
    let val (STRbind str, info) = look(strKey id)
     in strApplied(str,info,[id])
    end
val lookSTR = lookSTR' look
val lookSTRlocal = lookSTR' lookStrLocal

fun lookSTRinStr(STRstr{table,env,stamp,...},id,ap,qid,err) =
    (strApplied(lookSTRinTable(table,id),{path=ap,strenv=env},qid)
     handle UnboundTable => 
	(if stamp=bogusStrStamp then ()
	 else err("unbound structure in path: " ^ Symbol.name id);
	 bogusSTR))
  | lookSTRinStr _ = impossible "EnvAcc.lookSTRinStr"

fun bindSTR(id: symbol, strvar: structureVar) =
   let val binding = STRbind strvar
    in add(strIndex id, name id, binding);
       binding
   end

(* functors *)

fun lookFCT id = let val (FCTbind fv,_) = look(fctKey id) in fv end 

fun bindFCT(id: symbol, f: functorVar) = add(fctIndex id, name id, FCTbind f)

(* fixity bindings *)

fun lookFIX id = 
    if true (* !(Symbol.infixed id) *)
    then let val (FIXbind(FIXvar{binding,...}),_) = look(fixKey id)
	  in binding
	 end
	 handle Unbound => ((* Symbol.infixed id := false; *) NONfix)
    else NONfix

fun bindFIX(id: symbol, f: fixityVar) = 
   let val binding = FIXbind f
    in add(fixIndex id, name id, binding); binding
   end

(* lookup using symbolic path *)
fun lookPathinStr
      (str: Structure, ap: Access.path, spath as _::rest : symbol list,
       err: string -> unit,
       lookLast: Structure * symbol * Access.path * 
			symbol list * (string->unit) -> 'a) : 'a =
    let fun getStr([id],str,ap) = lookLast(str,id,ap,spath,err)
	  | getStr(id::rest,STRstr{table,stamp,env,...},ap) =
	      let val STRvar{access=SLOT n,binding,...} = 
		      lookSTRinTable(table,id)
		      handle UnboundTable => 
			(if stamp=bogusStrStamp then ()
		         else (err("unbound intermediate structure: "
				        ^ name id);
		               print "  in path: ";
			       printSequence "." printSym spath;
		               newline());
		         bogusSTR')
	       in getStr(rest,
		  	 (case binding
			   of INDstr i => 
			      (case env
			        of REL{s,...} => s sub i
			         | DIR => impossible "lookPathinStr.getStr 1")
			    | SHRstr(i::r) => 
			      (case env
			        of REL{s,...} => getEpath(r,s sub i)
			         | DIR => impossible "lookPathinStr.getStr 2")
			    | _ => binding),
			 n::ap)
	      end
	  | getStr _ = impossible "EnvAcc.lookPathinStr.getStr"
     in getStr(rest,str,ap)
    end
  | lookPathinStr _ = impossible "EnvAcc.lookPathinStr"

fun lookPathSTRinSig (spath as first::rest, err) : Structure * int list =
    let	fun complainUnbound() =
	    (err ("unbound structure in signature: " ^ formatQid spath);  
	     bogusSTR)
	(* second arg of get is expected to be a signature *)
	fun get([id],STRstr{table,env as REL{s,...},...}) = 
	     (case lookSTRinTable(table,id)
		   handle UnboundTable => complainUnbound()
	       of STRvar{binding=INDstr i,...} => (s sub i, [i])
		| STRvar{binding=SHRstr(p as i::r),...} =>
		    (getEpath(r,s sub i), p) (* not possible? *)
		| _ => impossible "lookPathSTRinSig.get")
	  | get(id::rest,STRstr{table,env=REL{s,...},...}) =
	      let val STRvar{binding=INDstr k,...} =
			lookSTRinTable(table,id)
			handle UnboundTable => complainUnbound()
		  val (str,p) = get(rest, s sub k)
	       in (str, k::p)
	      end
	  | get([],str) = (str,[])
	  | get _ = impossible "lookPathSTRinSig.get - bad args"
	fun lookInStr(str) =
	      (case rest
		 of [] => str
		  | _ => 
		    let val STRvar{binding,...} =
			    lookPathinStr(str, [], spath, err, lookSTRinStr)
		     in binding
		    end,
	       [1])
	val leadStr = lookSTR0 first
		      handle Unbound => (complainUnbound(),
					 {path = []:int list, 
					  strenv = Basics.DIR})
     in case leadStr
	  of (STRvar{binding=INDstr i,...},{path as h::r,strenv=REL{s,...}}) =>
		if h < 0 (* indicates signature component *)
		then let val (str,p) = get(rest, s sub i)
		      in (str,path@(i::p))
		     end
		else lookInStr(s sub i)
	   | (STRvar{binding=SHRstr(i::r),...},{strenv=REL{s,...},...}) =>
		lookInStr(getEpath(r, s sub i))
	   | (STRvar{binding as STRstr _,...},_) => lookInStr binding
	   | _ => impossible "lookPathSTRinSig - leadStr"
    end
  | lookPathSTRinSig _ = impossible "lookPathSTRinSig - bad arg"

fun lookPath (lookLast: Structure * symbol * Access.path * 
		symbol list * (string->unit) -> 'a)
	     (spath as first::rest, err: string->unit) : 'a =
    let	val STRvar{access=PATH(ap),binding,...} =
	      lookSTR first
	      handle Unbound => 
	        (err("unbound head structure: " ^ name first);
		 print "  in path: "; printSequence "." printSym spath;
		 newline();
		 bogusSTR)
     in lookPathinStr(binding,ap,spath,err,lookLast)
    end
  | lookPath _ _ = impossible "EnvAcc.lookPath"

val lookPathSTR = lookPath lookSTRinStr
val lookPathVARCON = lookPath lookVARCONinStr
val lookPathCON = lookPath lookCONinStr
val lookPathTYC = lookPath lookTYCinStr

fun lookPathArTYC ([id],a,err) = lookArTYC(id,a,err)
  | lookPathArTYC (path: symbol list, arity: int,err) =
    let val tyc = lookPathTYC (path, err)
     in checkArity(tyc,arity,err);
	tyc
    end

fun lookPathArTYCinSig depth ([id],a,err) = lookArTYCinSig depth (id,a,err)
  | lookPathArTYCinSig (depth: int) (spath as first::rest, arity,err) : tycon =
    let	fun complainUnbound() =
	    (err "unbound type constructor in signature";
	     print "  name: "; printSequence "." printSym spath;
	     newline();
	     raise Syntax)
	(* second arg of get is expected to be a signature *)
	fun get([id],STRstr{table,env as REL{t,...},...}) = 
	     (case lookTYCinTable(table,id)
		   handle UnboundTable => complainUnbound()
	       of INDtyc i => (checkArity(t sub i, arity,err); [i])
	        | SHRtyc p => (checkArity(getEpathTyc(p,env), arity,err); p)
		| _ => impossible "lookPathArTYCinSig.get")
	  | get(id::rest,STRstr{table,env=REL{s,...},...}) =
	      let val STRvar{binding=INDstr k,...} =
			lookSTRinTable(table,id)
			handle UnboundTable => complainUnbound()
	       in k::get(rest, s sub k)
	      end
	  | get([],_) = impossible "EnvAcc.lookPathArTYCinSig.get - empty path"
	  | get(p,NULLstr) =
	     (prSymPath(rev p); print "\n";
	      impossible "EnvAcc.lookPathArTYCinSig.get - NULLstr")
	  | get(p,INDstr _) =
	     (prSymPath(rev p); print "\n";
	      impossible "EnvAcc.lookPathArTYCinSig.get - INDstr")
	  | get(p,SHRstr _) =
	     (prSymPath(rev p); print "\n";
	      impossible "EnvAcc.lookPathArTYCinSig.get - SHRstr")
	  | get _ = impossible "EnvAcc.lookPathArTYCinSig.get - bad args"
	fun lookInStr(str) =
	    let val tyc = lookPathinStr(str, [], spath, err,lookTYCinStr)
	     in checkArity(tyc,arity,err);
		tyc
	    end
	val leadStr = lookSTR0 first
		      handle Unbound => complainUnbound()
     in case leadStr
	  of (STRvar{binding=INDstr i,...},{path=h::r,strenv=REL{s,...}}) =>
	      if h < 0 (* indicates signature component *)
	      then RELtyc(addzeros(depth+h,r@(i::get(rest, s sub i))))
	      else lookInStr(s sub i)
	   | (STRvar{binding=SHRstr(i::r),...},{strenv=REL{s,...},...}) =>
	        lookInStr(getEpath(r, s sub i))
	   | (STRvar{binding as STRstr _,...},_) => lookInStr binding
	   | _ => impossible "EnvAcc.lookPathArTYCinSig - leadStr"
    end
  | lookPathArTYCinSig _ _ = impossible "lookPathArTYCinSig - bad arg"

(* functions to collect stale lvars for unbinding *)
exception NotStale

fun checkopen(newenv,v) =
 let 
     fun test (i,s) =
	let val (_,{path,...}) = lookEnv(newenv,(i,s))
	    fun checklast [x] = if x=v then raise NotStale else ()
	      | checklast (a::r) = checklast r
	      | checklast nil = ()
	 in checklast path
        end

     fun trytable(STRstr{table,env,...}) =
         app (tryname env) (IntStrMp.intStrMapToList table) 
	 handle Unbound => ()

     and tryname _ (i,s,STRbind(STRvar{binding as STRstr _,...})) =
         (test(i,s); trytable binding)
       | tryname (REL{s,...}) (i',s',STRbind(STRvar{binding=INDstr i,...})) =
         (test(i',s'); trytable(s sub i))
      | tryname _ (i,s,_) = test(i,s)
 in tryname
end

fun staleLvars(newenv,oldenv) : int list =
    let val lvarset = ref([] : int list)
        fun collect (isb as (i,s,_)) = 
	  let val v = case lookEnv(oldenv,(i,s))
		       of (VARbind(VALvar{access=LVAR v,...}),_) => v
		        | (b as STRbind(STRvar{access=LVAR v,...}),
			     {path,strenv}) =>
				 (checkopen(newenv,v) strenv (i,s,b); v)
		        | (FCTbind(FCTvar{access=LVAR v,...}),_) => v
			| (CONbind(DATACON{rep=VARIABLE(LVAR v),...}),_) => v
		        | _ => raise NotStale
	   in lvarset := v :: !lvarset
	  end handle NotStale => ()
		   | Unbound => ()
     in appenv collect (newenv,oldenv);
        !lvarset
    end

end (* structure EnvAcc *)
