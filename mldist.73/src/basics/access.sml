(* Copyright 1989 by AT&T Bell Laboratories *)
(* access.sml *)

structure Access : ACCESS =
struct

  structure P = 
    struct 
      datatype primop = 
	! | * | + | - | := | < | <= | > | >= | lessu | gequ | alength |
        boxed | unboxed | div | cast |
	eql | fadd |fdiv |feql |fge |fgt |fle |flt |fmul |fneq |fsub |
	gethdlr | ieql | ineq | neq | makeref | ordof | profile |
	sethdlr | slength | callcc | capture | throw | delay | force |
	store | subscript | unboxedassign | unboxedupdate | update | ~ |
        inlsubscript | inlupdate | inlbyteof | inlstore | inlordof |
        floor | round | real | subscriptv | 
	subscriptf | updatef | inlsubscriptf | inlupdatef |
	rshift | lshift | orb | andb | xorb | notb |
	getvar | setvar | uselvar | deflvar 

      fun pr_primop(!) = "!"
      |   pr_primop(op * ) = "*" 
      |   pr_primop(op +)  = "+"
      |   pr_primop(op -) = "-"
      |   pr_primop(op :=) = ":="
      |   pr_primop(op <)  = "<"
      |   pr_primop(op <=) = "<="
      |   pr_primop(op >)  = ">"
      |   pr_primop(op >=) = ">="
      |   pr_primop(lessu) = "lessu"
      |   pr_primop(gequ) = "gequ"
      |   pr_primop (alength) = "alength"
      |   pr_primop(boxed) = "boxed"
      |   pr_primop(unboxed) = "unboxed"
      |   pr_primop (op div) = "div"
      |   pr_primop cast = "cast"
      |   pr_primop eql = "eql"
      |   pr_primop fadd = "fadd"
      |   pr_primop fdiv = "fdiv"
      |   pr_primop feql = "feql"
      |   pr_primop fge  = "fge"
      |   pr_primop fgt  = "fgt"
      |   pr_primop fle = "fle"
      |   pr_primop flt = "flt"
      |   pr_primop fmul = "fmul"
      |   pr_primop fneq = "fneq"
      |   pr_primop fsub = "fsub"
      |   pr_primop gethdlr = "gethdlr"
      |   pr_primop ieql = "ieql"
      |   pr_primop ineq = "ineq"
      |   pr_primop neq = "neq"
      |   pr_primop makeref = "makeref"
      |   pr_primop ordof = "ordof"
      |   pr_primop profile = "profile"
      |   pr_primop sethdlr = "sethdlr"
      |   pr_primop slength = "slength"
      |   pr_primop callcc = "callcc"
      |   pr_primop capture = "capture"
      |   pr_primop throw = "throw"
      |   pr_primop delay = "delay"
      |   pr_primop force = "force"
      |   pr_primop store = "store"
      |   pr_primop subscript = "subscript"
      |   pr_primop unboxedassign = "unboxedassign"
      |   pr_primop unboxedupdate = "unboxedupdate"
      |   pr_primop (op update) = "update"
      |   pr_primop(~) = "~"
      |   pr_primop(inlsubscript) = "inlsubscript"
      |   pr_primop(inlupdate) = "inlupdate"
      |   pr_primop(inlbyteof) = "inlbyteof"
      |   pr_primop(inlstore) = "inlstore"
      |   pr_primop(inlordof) = "inlordof"
      |   pr_primop(floor) = "floor"
      |   pr_primop(round) = "round"
      |   pr_primop(real) = "real"
      |   pr_primop(subscriptf) = "subscriptf"
      |   pr_primop(updatef) = "updatef"
      |   pr_primop(inlsubscriptf) = "inlsubscriptf"
      |   pr_primop(inlupdatef) = "inlupdatef"
      |   pr_primop(subscriptv) = "subscriptv"
      |   pr_primop(rshift) = "rshift"
      |   pr_primop(lshift) = "lshift"
      |   pr_primop(orb) = "orb"
      |   pr_primop(andb) = "andb"
      |   pr_primop(xorb) = "xorb"
      |   pr_primop(notb) = "notb"
      |   pr_primop(getvar) = "getvar"
      |   pr_primop(setvar) = "setvar"
      |   pr_primop(uselvar) = "uselvar"
      |   pr_primop(deflvar) = "deflvar"
    end

  type lvar = int      (* lambda variable id number *)
  type slot = int      (* position in structure record *)
  type path = int list (* slot chain terminated by lambda variable id number *)
  type primop = P.primop

  (* access: how to find the dynamic value corresponding to a variable.
    A PATH is an absolute address from a lambda-bound variable (i.e. we find
    the value of the lambda-bound variable, and then do selects from that).
    PATH's are kept in reverse order.   A SLOT is a position in a structure,
    and is relative to the address of the lambda-bound variable for the
    structure.   INLINE means that there is no dynamic value for the variable,
    which is a closed function: instead the compiler will generate "inline"
    code for the variable.  If we need a dynamic value, we must eta-expand
    the function.

    See modules.sig for the invariants of access paths in environments *)

  datatype access 
    = SLOT of slot
    | PATH of path  
    | INLINE of primop

  datatype conrep
      = UNDECIDED 
      | TAGGED of int 
      | CONSTANT of int 
      | TRANSPARENT 
      | TRANSU
      | TRANSB
      | REF
      | VARIABLE of access (* exception constructor *)
      | VARIABLEc of access (* exception constructor with no argument *)

  (* local *)
    val varcount = ref 0
    exception NoLvarName
    val lvarNames : string Intmap.intmap = Intmap.new(32, NoLvarName)
    val name = Intmap.map lvarNames
    val giveLvarName = Intmap.add lvarNames

  val saveLvarNames = System.Control.saveLvarNames
  fun mkLvar () : lvar = (inc varcount; !varcount)
  fun sameName(v,w) =
      if !saveLvarNames
      then giveLvarName(v,name w)
	     handle NoLvarName => (giveLvarName(w, name v)
				      handle NoLvarName => ())
      else ()
  fun dupLvar v =
      (inc varcount;
       if !saveLvarNames
       then giveLvarName(!varcount,name v) handle NoLvarName => ()
       else ();
       !varcount)
  fun namedLvar(id: Symbol.symbol) =
      (inc varcount;
       if !saveLvarNames then giveLvarName(!varcount,Symbol.name id) else ();
       !varcount)
  fun lvarName(lv : lvar) : string =
      (name lv ^ makestring lv) handle NoLvarName => makestring lv

  fun pr_lvar(lvar:lvar) = makestring(lvar)
  fun pr_slot(slot:slot) = makestring(slot)
  fun pr_path'[] = "]"
  |   pr_path'[x:int] = makestring x ^ "]"
  |   pr_path'((x:int)::rest)= makestring x ^ "," ^ pr_path' rest
  fun pr_path path = "[" ^ pr_path' path
  fun pr_access (SLOT slot) = "SLOT(" ^ pr_slot slot ^ ")"
  |   pr_access (PATH path) = "PATH(" ^ pr_path path ^ ")"
  |   pr_access (INLINE po) = "INLINE(" ^ P.pr_primop po ^ ")"

end  (* structure Access *)
