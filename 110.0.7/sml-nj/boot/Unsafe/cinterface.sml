(* cinterface.sml
 *
 * COPYRIGHT (c) 1994 AT&T Bell Laboratories.
 *
 *)

structure CInterface :> CINTERFACE =
  struct

    type c_function = Assembly.A.c_function

    val bindCFun = Assembly.A.bind_cfun

    exception CFunNotFound of string

    fun c_function moduleName funName = let
	  val cfun = bindCFun (moduleName, funName)
	  in
	    if (InlineT.cast cfun <> 0)
	      then fn x => (Assembly.A.callc (cfun, x))
	      else raise CFunNotFound(String.concat[moduleName, ".", funName])
	  end

    type system_const = (int * string)

    exception SysConstNotFound of string

    fun findSysConst (name, l) = let
	  fun look [] = NONE
	    | look ((sysConst : system_const)::r) = if (#2 sysConst = name)
		then SOME sysConst
		else look r
	  in
	    look l
	  end

    fun bindSysConst (name, l) = (case findSysConst(name, l)
	   of (SOME sc) => sc
	    | NONE => raise(SysConstNotFound name)
	  (* end case *))

  end (* structure CInterface *)

(*
 * $Log: cinterface.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:42  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.2  1997/09/12 18:01:17  jhr
 *   Revealed the bindCFun function.
 *
# Revision 1.1  1997/06/30  19:36:41  jhr
#   Removed System structure; added Unsafe structure.
#
 * Revision 1.1.1.1  1997/01/14  01:38:14  george
 *   Version 109.24
 *
 *)
