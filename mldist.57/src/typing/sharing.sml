(* Copyright 1989 by AT&T Bell Laboratories *)
(* sharing.sml *)

structure Sharing : SHARING =
struct

  structure Basics = Basics

  open ErrorMsg PrintUtil Basics EnvAccess TypesUtil

  val dummySym = Symbol.symbol "dummy"
  fun equalTycon(t1,t2) =
     let val a1 = tyconArity t1 and a2 = tyconArity t2
	 fun makeDummyType() =
	      CONty(mkABStyc([dummySym],0,YES,
			     Stampset.globalStamps),[])
	 fun makeargs 0 = [] 
	   | makeargs i = makeDummyType() :: makeargs(i-1)
	 val args = makeargs a1
      in if a1<>a2 then false else
		 (Unify.unifyTy(CONty(t1,args),CONty(t2,args)); true)
		 handle Unify.Unify s => false
     end

  exception DontBother

  (* a couple of useful iterators *)

  fun for a b = app b a

  fun upto (start,finish) f = 
      let fun loop i = if i>=finish then () else (f i; loop(i+1))
       in loop start
      end

  fun getStr([],str,err) = str
    | getStr(id::rest,STRstr{table,env,...},err) =
	let val STRvar{binding,...} = lookSTRinTable(table,id)
	    val str = case (binding,env)
		       of (INDstr i,REL{s,...}) => s sub i
			| (SHRstr(i::r),REL{s,...}) => getEpath(r, s sub i)
			| (STRstr _, _) => binding
			| _ => impossible "Sharing.getStr"
	 in getStr(rest,str,err)
	end
	handle Env.UnboundTable =>
	  (err COMPLAIN("unbound structure id in sharing specification: "
		  ^ Symbol.name id);
           raise DontBother)

  fun findStr(id::rest,table,env,err) : Structure =
       (let val STRvar{binding,...} = lookSTRinTable(table,id)
	    val str = case (binding,env)
			of (INDstr i,REL{s,...}) => s sub i
			 | (SHRstr(i::r),REL{s,...}) => getEpath(r,s sub i)
			 | (STRstr _, _) => binding
			 | _ => impossible "Sharing.findStr"
	 in getStr(rest,str,err)
	end
	handle Env.UnboundTable =>  (* look for global structure *)
	  let val STRvar{binding,...} =
		    lookSTR(id) handle Env.Unbound =>
		      (err COMPLAIN("unbound structure id in sharing specification: "
			      ^ Symbol.name id);
		       raise DontBother)
	   in getStr(rest,binding,err)
	  end)
    | findStr _ = impossible "Sharing.findStr with empty path"

  fun findTycon(path,table,env,err) : tycon =
      let val (id::rpath) = rev path 
       in case rev rpath
	    of [] => ((case lookTYCinTable(table,id)
			 of INDtyc i =>
			      (case env
				of REL{t,...} => t sub i
				 | DIR => impossible "Sharing.findTycon")
			  | SHRtyc p => getEpathTyc(p,env)
			  | tyc => tyc)
		      handle Env.UnboundTable =>
		      lookTYC id
		      handle Env.Unbound =>
		      (err COMPLAIN("unbound type in sharing spec: "^ Symbol.name id);
		       raise DontBother))
	     | path' => lookTYCinStr(findStr(path',table,env,err),id,(),(),complain)
      end

  fun doSharing(table,env as REL{s=senv,t=tenv},{strStamps,tycStamps},
		{s=strShare,t=typeShare}, err) =
      let fun freeStrStamp s = not(Stampset.member(s,strStamps))
          fun freeTycStamp s = not(Stampset.member(s,tycStamps))
	  val {assoc,getassoc,union,find} = Siblings.new(freeStrStamp)
	        : Structure Siblings.siblingClass
	  val {union=tunion,find=tfind} = Unionfind.new(freeTycStamp)

	  exception LookDEF
	  val DEFlist : (int * tycon) list ref = ref nil
	  fun enterDEF st = DEFlist := st :: !DEFlist
          fun lookDEF s =
		let fun f nil = raise LookDEF 
		      | f((s',t)::rest) = if s=s' then t else f rest
		 in f (!DEFlist)
		end
          fun setpath(DEFtyc{tyfun,...},path) = DEFtyc{tyfun=tyfun,path=path}

	  fun tycunion(t1,t2) =
	      let fun complain s = err COMPLAIN(s ^ " in sharing "
				          ^formatQid(rev(tycPath t1)) 
					   ^ "="^formatQid(rev(tycPath t2)))
		  fun tunion'(s1,s2) =
			(tunion(s1,s2); ())
			handle Unionfind.Union =>
			  if equalTycon(lookDEF(tfind s1),lookDEF(tfind s2))
			   then () else complain "type mismatch"
	       in if tyconArity t1 <> tyconArity t2
		then complain "inconsistent arities"
		else case (t1,t2)
		      of (GENtyc{stamp=s1,...},GENtyc{stamp=s2,...}) =>
			   tunion'(s1,s2)
		       | (DEFtyc _, DEFtyc _) => 
			    if equalTycon(t1,t2) then ()
			    else complain "different global type constructors"
		       | (DEFtyc _, GENtyc _) => tycunion(t2,t1)
		       | (GENtyc{stamp,...}, DEFtyc _) =>
			  let val s = Stampset.newStamp Stampset.fixedTycStamps
			   in enterDEF(s,t2);
			      tunion'(s,stamp)
			  end
	      end

	  fun getname (STRkind{path}) = formatQid path
	    | getname _ = "?"
	  fun strMerge(p' as STRstr{stamp=p,kind=pk,...},
		       q' as STRstr{stamp=q,kind=qk,...}) =
	      if (assoc(p,p'); find p) = (assoc(q,q'); find q)
	      then ()
	      else let val pclass = getassoc p
		       and qclass = getassoc q
		    in union(p,q);
		       for pclass (fn x =>
			 for qclass (fn y =>
			   sMerge(x,y)))
		   end
		handle Unionfind.Union =>
		err COMPLAIN ("illegal global structure sharing "^
				getname pk ^"="^getname qk)

	  and sMerge(str1 as STRstr{stamp=s1,kind=k1,env=env1,...},
		     str2 as STRstr{stamp=s2,kind=k2,env=env2,table,...}) =
	      case (k1,k2)
		of (STRkind _, STRkind _) =>
		      if s1 = s2
		      then ()
		      else err COMPLAIN "sharing constraint - \
				   \incompatible fixed structures"
		 | (STRkind _, SIGkind _) => sMerge(str2,str1)
		 | (SIGkind{bindings,...},  _) =>
		   let val REL{s=senv1,t=tenv1} = env1 in
		     for bindings 
		       (fn STRbind(STRvar{name=[id],binding,...}) =>
			    (let val STRvar{binding=target,...} =
				       lookSTRinTable(table,id)
			      in strMerge((case binding
					     of INDstr i => senv1 sub i 
					      | _ => binding),
					  (case env2
					     of REL{s=senv2,...} =>
						 (case target
						    of INDstr i => senv2 sub i
						     | SHRstr(i::r) =>
							 getEpath(r,senv2 sub i)
						     | _ => target)
					      | DIR => target))
			     end
			     handle Env.UnboundTable => ())
			 | TYCbind(tycon) =>
			    (let val tyc1 = case tycon
					      of INDtyc i => tenv1 sub i
					       | _ => tycon
			         val tyc2' = lookTYCinTable(table,tycName tyc1)
				 val tyc2 = 
				     case env2
				       of REL{t=tenv2,...} =>
					   (case tyc2'
					      of INDtyc i => tenv2 sub i 
					       | SHRtyc p => getEpathTyc(p,env2)
					       | tyc => tyc)
					| DIR => tyc2'
			      in tycunion(tyc1,tyc2);
				 ()
			     end
			     handle Env.UnboundTable => ())
			 | _ => ())
		   end

	  fun shareSig(REL{s,t}) =
	      (upto (2, Array.length s) (fn i =>
		 let val str as STRstr{stamp,sign,table,env as REL{s=s',...},kind} =
			   s sub i
		  in case kind
		      of SIGkind _ => 
			   let val stamp' = find stamp
			    in if stamp' = stamp
			       then ()
			       else let val new =
					   STRstr{stamp=stamp',sign=sign,
						  table=table,
						  env=env,kind=kind}
				     in update(s,i,new);
					ArrayExt.app(ModUtil.resetParent new,s',1)
				    end;
			       shareSig env
			   end
		       | STRkind _ => impossible "Sharing.doSharing.shareSig"
		 end);
	       upto (0,Array.length t) (fn i =>
		case t sub i
		 of GENtyc{stamp,path,arity,eq,kind} =>
			let val stamp' = tfind stamp
			 in if stamp=stamp'
			    then ()
			    else update(t,i,
				   setpath(lookDEF stamp', path)
				   handle LookDEF => 
					GENtyc{stamp=stamp',path=path,
					       arity=arity,eq=eq,kind=kind})
			end
		  | DEFtyc _ => ()
		  | _ => impossible "Sharing.doSharing.484"))
	    | shareSig(DIR) = impossible "Sharing.doSharing.shareSig 2"

	  val strPathPairs = ref [] : (spath*spath) list ref
	  val typePathPairs = ref [] : (spath*spath) list ref

       in for strShare (fn p as (p1,p2) =>
	    let val str1 as STRstr{stamp=s1,...} = findStr(p1,table,env,err)
		and str2 as STRstr{stamp=s2,...} = findStr(p2,table,env,err)
	     in if freeStrStamp s1 orelse freeStrStamp s2 then ()
		  else strPathPairs := p :: !strPathPairs;
		strMerge(str1,str2)
	    end handle DontBother => ());
	  for typeShare (fn p as (p1,p2) =>
	     (case (findTycon(p1,table,env,err),findTycon(p2,table,env,err))
	      of (t1 as GENtyc{stamp=s1,...}, t2 as GENtyc{stamp=s2,...}) =>
	          (if freeTycStamp s1 orelse freeTycStamp s2 then ()
		     else typePathPairs := p :: !typePathPairs;
	          tycunion(t1,t2))
	       | (t1,t2) => tycunion(t1,t2))
	      handle DontBother => ());
	  shareSig env;
	  {s= !strPathPairs, t= !typePathPairs}
      end  (* doSharing *)

  fun checkSharing(table,env,{s=strShare,t=typeShare},err) =
      (for strShare (fn p as (p1,p2) =>
	 let val STRstr{stamp=s1,...} = findStr(p1,table,env,err)
	     and STRstr{stamp=s2,...} = findStr(p2,table,env,err)
	  in if s1 <> s2
	     then (err COMPLAIN "structure sharing violation";
		   print "  "; prSymPath p1; print " # "; prSymPath p2; newline())
	     else ()
	 end handle DontBother => ());
       for typeShare (fn (p1,p2) =>
	 let val tyc1 = findTycon(p1,table,env,err)
	     and tyc2 = findTycon(p2,table,env,err)
	  in if equalTycon(tyc1,tyc2)
	     then ()
	     else (err COMPLAIN "type sharing violation:";
		   print "  "; prSymPath p1; print " # "; prSymPath p2; newline())
	 end handle DontBother => ()))

end (* structure Sharing *)
