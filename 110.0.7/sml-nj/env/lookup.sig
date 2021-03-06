(* COPYRIGHT 1996 Bell Laboratories *)
(* lookup.sig *)

signature LOOKUP =
sig
  val lookFix : StaticEnv.staticEnv * Symbol.symbol -> Fixity.fixity

  val lookSig : StaticEnv.staticEnv * Symbol.symbol * ErrorMsg.complainer
                -> Modules.Signature

  val lookFsig : StaticEnv.staticEnv * Symbol.symbol * ErrorMsg.complainer 
		 -> Modules.fctSig

  val lookStr : StaticEnv.staticEnv * SymPath.path * ErrorMsg.complainer
                -> Modules.Structure

  val lookStrDef : StaticEnv.staticEnv * SymPath.path * ErrorMsg.complainer
                   -> Modules.strDef

  val lookFct : StaticEnv.staticEnv * SymPath.path * ErrorMsg.complainer
                -> Modules.Functor

  val lookTyc : StaticEnv.staticEnv * SymPath.path * ErrorMsg.complainer
                -> Types.tycon

  val lookArTyc : StaticEnv.staticEnv * SymPath.path * int 
                    * ErrorMsg.complainer -> Types.tycon

  (* lookValSym and lookSym return value or constructor bindings *)
  val lookValSym : StaticEnv.staticEnv * Symbol.symbol * ErrorMsg.complainer
		   -> VarCon.value

  val lookVal : StaticEnv.staticEnv * SymPath.path * ErrorMsg.complainer
                -> VarCon.value

  val lookExn : StaticEnv.staticEnv * SymPath.path * ErrorMsg.complainer
                -> VarCon.datacon

end (* signature LOOKUP *)

(*
 * $Log: lookup.sig,v $
 * Revision 1.1.1.1  1999/12/03 19:59:45  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.2  1997/05/20 12:20:19  dbm
 *   SML '97 sharing, where structure.
 *
 * Revision 1.1.1.1  1997/01/14  01:38:36  george
 *   Version 109.24
 *
 *)
