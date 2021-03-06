(* COPYRIGHT (c) 1996 Bell Laboratories *)
(* pickmod.sml *)

signature PICKMOD =
sig
  val pickleEnv : 
        SCStaticEnv.staticEnv * StaticEnv.staticEnv 
                  -> {hash: PersStamps.persstamp,
                      pickle: Word8Vector.vector, 
	              exportLvars: Lambda.lvar list,
	              exportPid: PersStamps.persstamp option}

  val pickleLambda:
        Lambda.lexp option ->
                 {hash: PersStamps.persstamp, pickle: Word8Vector.vector}

  val pickle2hash: Word8Vector.vector -> PersStamps.persstamp

  val dontPickle : 
        StaticEnv.staticEnv * int
                  -> StaticEnv.staticEnv * PersStamps.persstamp *
	             Lambda.lvar list * PersStamps.persstamp option

  val debugging : bool ref
  val debuggingSW : bool ref

end (* signature PICKMOD *)

structure PickMod : PICKMOD = 
struct

local structure A  = Access
      structure B  = Bindings
      structure DI = DebIndex
      structure EP = EntPath
      structure ED = EntPath.EvDict
      structure II = InlInfo
      structure IP = InvPath
      structure L  = Lambda
      structure LK = LtyKernel
         (** pickmod must look under the abstract lty representation *)
      structure M  = Modules 
      structure MI = ModuleId
      structure P  = PrimOp
      structure PS = PersStamps
      structure PT = PrimTyc
      structure S  = Symbol
      structure SP = SymPath 
      structure T  = Types 
      structure TU = TypesUtil
      structure V  = VarCon 
      structure LtyKey : ORD_KEY = 
        struct type ord_key = LK.lty * DI.depth
               fun cmpKey((t,d),(t',d')) =
                   case LK.lt_cmp(t,t') of EQUAL => DI.cmp(d,d')
                                         | x => x
        end
      structure LtyDict = BinaryDict(LtyKey)
in 

val say = Control.Print.say
val debugging = ref true
fun debugmsg (msg: string) =
  if !debugging then (say msg; say "\n") else ()
fun bug msg = ErrorMsg.impossible ("PickMod: " ^ msg)

fun isGlobalStamp(Stamps.STAMP{scope=Stamps.GLOBAL _,...}) = true
  | isGlobalStamp _ = false

val addPickles = Stats.addStat(Stats.makeStat "Pickle Bytes")

(**************************************************************************
 *                      UTILITY FUNCTIONS                                 *
 **************************************************************************)
datatype key 
  = MIkey of MI.modId
  | LTkey of LK.lty
  | TCkey of LK.tyc
  | TKkey of LK.tkind
  | DTkey of Stamps.stamp
  | EPkey of EP.entPath

structure Key =
  struct
    type ord_key = key

    fun cmpKey(MIkey a', MIkey b') = MI.cmp(a',b')
      | cmpKey(MIkey _, _) = GREATER
      | cmpKey(_, MIkey _) = LESS 
      | cmpKey(LTkey a', LTkey b') = LK.lt_cmp(a',b')
      | cmpKey(LTkey _, _) = GREATER
      | cmpKey(_, LTkey _) = LESS 
      | cmpKey(TCkey a', TCkey b') = LK.tc_cmp(a',b')
      | cmpKey(TCkey _, _) = GREATER
      | cmpKey(_, TCkey _) = LESS 
      | cmpKey(TKkey a', TKkey b') = LK.tk_cmp(a',b')
      | cmpKey(TKkey _, _) = GREATER
      | cmpKey(_, TKkey _) = LESS 
      | cmpKey(DTkey a', DTkey b') = Stamps.cmp(a',b')
      | cmpKey(DTkey _, _) = GREATER
      | cmpKey(_, DTkey _) = LESS 
      | cmpKey(EPkey a', EPkey b') = EP.cmpEntPath(a', b')
(*    
      | cmpKey(EPkey _, _) = GREATER
      | cmpKey(_, EPkey _) = LESS 
*)


  end (* structure Key *)

structure W = ShareWrite(Key)

val debuggingSW = W.debugging

val $ = W.$
infix $ 

val nilEncode = "Na" $ []

fun list alpha nil () = nilEncode
  | list alpha [a] () = "1a" $ [alpha a]
  | list alpha [a,b] () = "2a" $ [alpha a, alpha b]
  | list alpha [a,b,c] () = "3a" $ [alpha a, alpha b, alpha c]
  | list alpha [a,b,c,d] () = "4a" $ [alpha a, alpha b, alpha c, alpha d]
  | list alpha [a,b,c,d,e] () =
      "5a" $ [alpha a, alpha b, alpha c, alpha d, alpha e]
  | list alpha (a::b::c::d::e::rest) () =
      "Ma" $ [alpha a, alpha b, alpha c, alpha d, alpha e, list alpha rest]

fun tuple2 (alpha,beta) (x,y) () = "Tb" $ [alpha x, beta y]

fun option alpha (SOME x) () = "Sc" $ [alpha x]
  | option alpha NONE () = "Nc" $ []

fun bool true () = "Td" $ []
  | bool false() = "Fd" $ []

fun persstamp x = W.w8vector (PS.toBytes x)

fun symbol s () = 
  let val code = 
        case S.nameSpace s 
	 of S.VALspace => "Ap"
	  | S.TYCspace => "Bp"
	  | S.SIGspace => "Cp"
	  | S.STRspace => "Dp"
	  | S.FCTspace => "Ep"
	  | S.FIXspace => "Fp"
	  | S.LABspace => "Gp"
	  | S.TYVspace => "Hp"
	  | S.FSIGspace=> "Ip"
   in code $ [W.string(S.name s)]
  end

val int = W.int
val word = W.string o Word.toString
val word32 = W.string o Word32.toString
val int32 = W.string o Int32.toString

(* val apath = int list *)

fun numkind (P.INT i)   () = "Ig" $ [int i]
  | numkind (P.UINT i)  () = "Ug" $ [int i]
  | numkind (P.FLOAT i) () = "Fg" $ [int i]

fun arithop P.+ () = "ah" $ []
  | arithop P.- () = "bh" $ []
  | arithop P.* () = "ch" $ []
  | arithop P./ () = "dh" $ []
  | arithop P.~ () = "eh" $ []
  | arithop P.ABS () = "fh" $ []
  | arithop P.LSHIFT () = "gh" $ []
  | arithop P.RSHIFT () = "hh" $ []
  | arithop P.RSHIFTL () = "ih" $ []
  | arithop P.ANDB () = "jh" $ []
  | arithop P.ORB () = "kh" $ []
  | arithop P.XORB () = "lh" $ []
  | arithop P.NOTB () = "mh" $ []

fun cmpop P.> () = "ai" $ []
  | cmpop P.>= () = "bi" $ []
  | cmpop P.< () = "ci" $ []
  | cmpop P.<= () = "di" $ []
  | cmpop P.LEU () = "ei" $ []
  | cmpop P.LTU () = "fi" $ []
  | cmpop P.GEU () = "gi" $ []
  | cmpop P.GTU () = "hi" $ []
  | cmpop P.EQL () = "ii" $ []
  | cmpop P.NEQ () = "ji" $ []

fun primop (P.ARITH{oper=p,overflow=v,kind=k}) () = 
      "Aj" $ [arithop p, bool v, numkind k]
  | primop (P.CMP{oper=p,kind=k}) () = 
      "Cj" $ [cmpop p, numkind k]

  | primop (P.TEST(from,to)) () = "Gj" $ [int from, int to]
  | primop (P.TESTU(from,to)) () = "Hj" $ [int from, int to]
  | primop (P.TRUNC(from,to)) () = "Ij" $ [int from, int to]
  | primop (P.EXTEND(from,to)) () = "Jj" $ [int from, int to]
  | primop (P.COPY(from,to)) () = "Kj" $ [int from, int to]

  | primop (P.INLLSHIFT k) () = "<j" $ [numkind k]
  | primop (P.INLRSHIFT k) () = ">j" $ [numkind k]
  | primop (P.INLRSHIFTL k) () = "Lj" $ [numkind k] 

  | primop (P.ROUND{floor=f,fromkind=k,tokind=t}) () =
      "Rj" $ [bool f, numkind k, numkind t]
  | primop (P.REAL{fromkind=k,tokind=t}) () =
      "Fj" $ [numkind k, numkind t]
  | primop (P.NUMSUBSCRIPT{kind=k,checked=c,immutable=i}) () =
      "Sj" $ [numkind k, bool c, bool i]
  | primop (P.NUMUPDATE{kind=k,checked=c}) () =
      "Uj" $ [numkind k, bool c]
  | primop (P.INL_MONOARRAY k) () = "Mj" $ [numkind k]
  | primop (P.INL_MONOVECTOR k) () = "Vj" $ [numkind k]

  | primop P.SUBSCRIPT () = "ak" $ []
  | primop P.SUBSCRIPTV () = "bk" $ []
  | primop P.INLSUBSCRIPT () = "ck" $ []
  | primop P.INLSUBSCRIPTV () = "dk" $ []
  | primop P.INLMKARRAY () = "~k" $ []

  | primop P.PTREQL () = "ek" $ []
  | primop P.PTRNEQ () = "fk" $ []
  | primop P.POLYEQL () = "gk" $ []
  | primop P.POLYNEQ () = "hk" $ []
  | primop P.BOXED () = "ik" $ []
  | primop P.UNBOXED () = "jk" $ []
  | primop P.LENGTH () = "kk" $ []
  | primop P.OBJLENGTH () = "lk" $ []
  | primop P.CAST () = "mk" $ []
  | primop P.GETRUNVEC () = "nk" $ []
  | primop P.MARKEXN () = "[k" $ []
  | primop P.GETHDLR () = "ok" $ []
  | primop P.SETHDLR () = "pk" $ []
  | primop P.GETVAR () = "qk" $ []
  | primop P.SETVAR () = "rk" $ []
  | primop P.GETPSEUDO () = "sk" $ []
  | primop P.SETPSEUDO () = "tk" $ []
  | primop P.SETMARK () = "uk" $ []
  | primop P.DISPOSE () = "vk" $ []
  | primop P.MAKEREF () = "wk" $ []
  | primop P.CALLCC () = "xk" $ []
  | primop P.CAPTURE () = "yk" $ []
  | primop P.THROW () = "zk" $ []
  | primop P.DEREF () = "1k" $ []
  | primop P.ASSIGN () = "2k" $ []
  | primop P.UPDATE () = "3k" $ []
  | primop P.INLUPDATE () = "4k" $ []
  | primop P.BOXEDUPDATE () = "5k" $ []
  | primop P.UNBOXEDUPDATE () = "6k" $ []

  | primop P.GETTAG () = "7k" $ []
  | primop P.MKSPECIAL () = "8k" $ []
  | primop P.SETSPECIAL () = "9k" $ []
  | primop P.GETSPECIAL () = "0k" $ []
  | primop P.USELVAR () = "!k" $ []
  | primop P.DEFLVAR () = "@k" $ []
  | primop P.INLDIV () = "#k" $ []
  | primop P.INLMOD () = "$k" $ []
  | primop P.INLREM () = "%k" $ []
  | primop P.INLMIN () = "^k" $ []
  | primop P.INLMAX () = "&k" $ []
  | primop P.INLABS () = "*k" $ []
  | primop P.INLNOT () = "(k" $ []
  | primop P.INLCOMPOSE () = ")k" $ []
  | primop P.INLBEFORE () = ",k" $ []
  | primop P.INL_ARRAY () = ".k" $ []
  | primop P.INL_VECTOR () = "/k" $ []
  | primop P.ISOLATE () = ":k" $ []

fun consig (A.CSIG(i,j)) () = "S8" $ [W.int i, W.int j]
  | consig (A.CNIL) () = "N8" $ []

fun mkAccess var = 
  let fun access (A.LVAR i)      () = "Ll" $ [var i]
        | access (A.EXTERN p)    () = "El" $ [persstamp p]
        | access (A.PATH(a,i))   () = "Pl" $ [int i, access a]
        | access (A.NO_ACCESS)   () = "Nl" $ []

      fun conrep (A.UNTAGGED) () = "Um" $ []
	| conrep (A.TAGGED i) () = "Tm" $ [int i]
	| conrep (A.TRANSPARENT) () = "Bm" $ []
	| conrep (A.CONSTANT i) () = "Cm" $ [int i]
	| conrep (A.REF) () = "Rm" $ []
	| conrep (A.EXNFUN a) () = "Vm" $ [access a]
	| conrep (A.EXNCONST a) () = "Wm" $ [access a]
	| conrep (A.LISTCONS) () = "Lm" $ []
	| conrep (A.LISTNIL) () = "Nm" $ []

  in {access=access,conrep=conrep}
 end

fun alphaConverter () = 
  let exception AlphaCvt
      val m: int Intmap.intmap = Intmap.new (32, AlphaCvt)
      val alphacount = ref 0
      fun alphaConvert i = 
        (Intmap.map m i
         handle AlphaCvt => (let val j = !alphacount
			      in alphacount := j+1;
			         Intmap.add m (i,j);
			         j
		             end))
   in alphaConvert
  end

fun mkStamp alphaConvert =
  let fun stamp (Stamps.STAMP{scope=Stamps.LOCAL, count=i}) () =
	    "Le" $ [W.int(alphaConvert i)]
        | stamp (Stamps.STAMP{scope=Stamps.GLOBAL pid, count=i}) () =
	    "Ge" $ [persstamp pid, W.int i]
        | stamp (Stamps.STAMP{scope=Stamps.SPECIAL s, count=i}) () =
	    "Se" $ [W.string s, W.int i]
   in stamp
  end

(** NOTE: the CRC functions really ought to work on Word8Vector.vectors **)
fun pickle2hash pickle =
  PS.fromBytes(Byte.stringToBytes(CRC.toString(
                    CRC.fromString(Byte.bytesToString pickle))))


(**************************************************************************
 *                  PICKLING A LAMBDA EXPRESSIONS                         *
 **************************************************************************)

fun mkPickleLty (stamp,tvar) =
    let fun ltyI x () =
	  (case LK.lt_out x
	    of LK.LT_TYC tc   => "An" $ [tyc tc]
	     | LK.LT_STR l    => "Bn" $ [list lty l]
	     | LK.LT_PST l    => "Cn" $ [list (tuple2 (int, lty)) l]
	     | LK.LT_FCT (t1,t2) => "Dn" $ [lty t1, lty t2]
	     | LK.LT_POLY(ks,t)  => "En" $ [list tkind ks, lty t]
             | LK.LT_IND _ => 
                 bug "unexpected LT_IND in mkPickeLty"
             | LK.LT_ENV (lt,ol,nl,te) => 
                 bug "unexpected LT_ENV in mkPickeLty"
(*               "Fn" $ [lty lt, int ol, int nl, tycEnv te] *)
             | LK.LT_CNT _ => bug "unexpected LT_CNT in mkPickeLty")

        and lty x () =
	  if (LK.ltp_norm x) then
            (W.identify (LTkey x) (fn () => ltyI x ()))
          else ltyI x ()
            (* bug "unexpected complex lambda type in mkPickleLty" *)

        and tycI x () = 
	  (case LK.tc_out x
	    of LK.TC_VAR(db,i) => "A6" $ [int(DI.di_toint db), int i]
	     | LK.TC_PRIM t => "B6" $ [int(PT.pt_toint t)]
             | LK.TC_FN(ks,tc) => "C6" $ [list tkind ks, tyc tc]
             | LK.TC_APP(tc,l) => "D6" $ [tyc tc, list tyc l]
             | LK.TC_SEQ l => "E6" $ [list tyc l]
             | LK.TC_PROJ(tc,i) => "F6" $ [tyc tc, int i]
             | LK.TC_SUM l => "G6" $ [list tyc l]
             | LK.TC_FIX(tc,i) => "H6" $ [tyc tc, int i]
             | LK.TC_ABS tc => "I6" $ [tyc tc]
             | LK.TC_BOX tc => "J6" $ [tyc tc]
             | LK.TC_TUPLE l => "K6" $ [list tyc l]
             | LK.TC_ARROW (t1,t2) => "L6" $ [tyc t1, tyc t2]
             | LK.TC_IND _ => bug "unexpected TC_IND in mkPickleLty"
             | LK.TC_ENV (tc, ol, nl, te) => 
                 bug "unexpected TC_ENV in mkPickleLty"
(*               "M6" $ [tyc tc, int ol, int nl, tycEnv te] *)
             | LK.TC_CONT _ => bug "unexpected TC_CONT in mkPickleLty")

        and tyc x () =
          if (LK.tcp_norm x) then
	    (W.identify (TCkey x) (fn () => tycI x ()))
          else tycI x ()
            (* bug "unexpected complex lambda tyc in mkPickleLty" *)

        and tkind x () =
	  W.identify (TKkey x)
	    (fn ()=>
	     case LK.tk_out x
              of LK.TK_TYC => "A7" $ []
               | LK.TK_TBX => "B7" $ []
               | LK.TK_SEQ ks => "C7" $ [list tkind ks]
               | LK.TK_FUN(k1,k2) => "D7" $ [tkind k1, tkind k2])

        and tycEnv x () = list (tuple2 (option (list tyc), int)) x ()
 
     in {lty=lty,tyc=tyc,tkind=tkind}
    end
 
fun pickleLambda leOp =
  let val alphaConvert = alphaConverter()
      val stamp = mkStamp alphaConvert
      val lvar = int o alphaConvert
      val tvar = lvar
      val {access,conrep} = mkAccess lvar
      val {lty,tyc,tkind} = mkPickleLty(stamp,tvar)
	
      fun con (L.DATAcon (s, cr, t), e) () =
	    ".5" $ [symbol s, conrep cr, lty t, lexp e]
        | con (L.INTcon i, e) ()           = ",5" $ [int i, lexp e]
        | con (L.INT32con i32, e) ()       = "=5" $ [int32 i32, lexp e]
        | con (L.WORDcon w, e) ()          = "?5" $ [word w, lexp e]
        | con (L.WORD32con w32, e) ()      = ">5" $ [word32 w32, lexp e]
        | con (L.REALcon s, e) ()          = "<5" $ [W.string s, lexp e]
        | con (L.STRINGcon s, e) ()        = "'5" $ [W.string s, lexp e]
        | con (L.VLENcon i, e) ()          = ";5" $ [int i, lexp e]

      and dict {default=v, table=tbls} () = 
            "%5" $ [lvar v, list (tuple2 (list tyc, lvar)) tbls]

      and sval (L.VAR v) ()               = "a5" $ [lvar v]
	| sval (L.INT i) ()               = "b5" $ [int i]
	| sval (L.INT32 i32) ()           = "z5" $ [int32 i32]
	| sval (L.WORD w) ()              = "c5" $ [word w]
	| sval (L.WORD32 w32) ()          = "d5" $ [word32 w32]
	| sval (L.REAL s) ()              = "e5" $ [W.string s]
	| sval (L.STRING s) ()            = "f5" $ [W.string s]
	| sval (L.PRIM (p, t, ts)) ()     = 
            "g5" $ [primop p, lty t, list tyc ts]
        | sval (L.GENOP (dt, p, t, ts)) ()   = 
            "h5" $ [dict dt, primop p, lty t, list tyc ts]

      and lexp (L.SVAL sv) ()             = "i5" $ [sval sv]
	| lexp (L.FN (v, t, e)) ()        = "j5" $ [lvar v, lty t, lexp e]
	| lexp (L.FIX (vl, tl, el, e)) () = 
	    "k5" $ [list lvar vl, list lty tl, list lexp el, lexp e]
	| lexp (L.APP (v1, v2)) ()        = "l5" $ [sval v1, sval v2]
	| lexp (L.SWITCH (v, crl, cel, eo)) () =
	    "m5" $ [sval v, consig crl, list con cel, option lexp eo]
	| lexp (L.CON ((s, cr, t), ts, v)) () =
	    "n5" $ [symbol s, conrep cr, lty t, list tyc ts, sval v]
	| lexp (L.DECON ((s, cr, t), ts, v)) () =
	    "o5" $ [symbol s, conrep cr, lty t, list tyc ts, sval v]
	| lexp (L.VECTOR (vl, t)) ()           = "p5" $ [list sval vl, tyc t]
	| lexp (L.RECORD vl) ()           = "q5" $ [list sval vl]
	| lexp (L.SRECORD vl) ()          = "r5" $ [list sval vl]
	| lexp (L.RAISE (v, t)) ()        = "s5" $ [sval v, lty t]
	| lexp (L.HANDLE (e, v)) ()     = "t5" $ [lexp e, sval v]
	| lexp (L.WRAP (t, b, v)) ()         = "u5" $ [tyc t, bool b, sval v]
	| lexp (L.UNWRAP (t, b, v)) ()       = "v5" $ [tyc t, bool b, sval v]
        | lexp (L.SELECT (i, v)) ()       = "w5" $ [int i, sval v]

	| lexp (L.TFN(ks, e)) ()          = "x5" $ [list tkind ks, lexp e]
	| lexp (L.TAPP(v, ts)) ()         = "y5" $ [sval v, list tyc ts]
        | lexp (L.LET(v, e1, e2)) ()      = "05" $ [lvar v, lexp e1, lexp e2]
	| lexp (L.PACK(t, ts, nts, v)) ()         = 
            "15" $ [lty t, list tyc ts, list tyc nts, sval v]
	| lexp (L.EXNF (v, t)) ()         = "25" $ [sval v, lty t]
	| lexp (L.EXNC v) ()              = "35" $ [sval v]
   
      val pickle = W.pickle (option lexp leOp)
      val hash = pickle2hash pickle
   in {pickle = pickle, hash = hash}
  end


(**************************************************************************
 *                    PICKLING AN ENVIRONMENT                             *
 **************************************************************************)

fun pickleEnv(context0, e0: B.binding Env.env) =
let val alphaConvert = alphaConverter ()
    val stamp = mkStamp alphaConvert
    val entVar = stamp
    val entPath = list entVar

    fun modId (MI.STRid{rlzn=a,sign=b}) () = "Bf" $ [stamp a, stamp b]
      | modId (MI.SIGid s) () = "Cf" $ [stamp s]
      | modId (MI.FCTid{rlzn=a,sign=b}) () = "Ef" $ [stamp a, modId b]
      | modId (MI.FSIGid{paramsig=a,bodysig=b}) () = "Ff" $ [stamp a, stamp b]
      | modId (MI.TYCid a) () = "Gf" $ [stamp a]
      | modId (MI.EENVid s) () = "Vf" $ [stamp s]

    val lvcount = ref 0
    val lvlist = ref ([]: LambdaVar.lvar list)

    fun anotherLvar v =
      let val j = !lvcount
       in lvlist := v :: !lvlist;
	  lvcount := j+1; 
	  j
      end

    val {access,conrep} = mkAccess (int o anotherLvar)
    val {lty,tkind,...} = mkPickleLty(stamp, int o alphaConvert)

    (* SP.path and IP.path are both treated as symbol lists *)
    fun spath (SP.SPATH p) = list symbol p
    fun ipath (IP.IPATH p) = list symbol p

    val label = symbol

    fun eqprop T.YES () = "Yq" $ []
      | eqprop T.NO  () = "Nq" $ []
      | eqprop T.IND () = "Iq" $ []
      | eqprop T.OBJ () = "Oq" $ []
      | eqprop T.DATA() = "Dq" $ []
      | eqprop T.ABS () = "Aq" $ []
      | eqprop T.UNDEF()= "Uq" $ []

    fun datacon (T.DATACON{name=n,const=c,typ=t,rep=r,sign=s}) () =
	  "Dr" $ [symbol n, bool c, ty t, conrep r, consig s]

    and tyckind (T.PRIMITIVE pt) () = "Ps" $ [int (PT.pt_toint pt)] 
      | tyckind (T.DATATYPE{index=i, members=v, ...}) () = 
	 if Vector.length v = 0
	 then bug "empty dtmember during pickling"
	 else let val {stamp=s,...} = Vector.sub(v,0)
	       in "Ds" $ [W.int i,
			 fn()=>W.identify (DTkey s)
			       (list dtmember (Vector.foldr (op ::) nil v))]
	      end
      | tyckind (T.ABSTRACT tyc) () = "As" $ [tycon tyc]
      | tyckind (T.FLEXTYC tps) () = 
          (*** tycpath should never be pickled; the only way it can be
               pickled is when pickling the domains of a mutually 
               recursive datatypes; right now the mutually recursive
               datatypes are not assigned accurate domains ... (ZHONG)
               the following code is just a temporary gross hack. 
           ***)
           "Fs" $ [] (* "Ss" $ [tycpath tps] *)
      | tyckind (T.FORMAL) () = "Fs" $ []
      | tyckind (T.TEMP) () = "Ts" $ []

    and tycpath _ () = bug "unexpected tycpath during the pickling"

    and dtmember {tycname=n,stamp=s,dcons=d,arity=i,eq=ref e,sign=sn, lambdatyc} () =
          "Tt" $ [symbol n, stamp s, list nameRepDomain d, int i, eqprop e,
		  consig sn]

    and nameRepDomain {name=n,rep=r,domain=t} () =
	  "Nu" $ [symbol n, conrep r, option ty t]

    and tycon (T.GENtyc{stamp=s, arity=a, eq=ref e, kind=k, path=p}) () =
	  let val id = MI.TYCid s
	   in W.identify(MIkey id)
		(fn()=> case SCStaticEnv.lookTYC context0 id
			 of SOME _ => "Xv" $ [modId id]
			  | NONE => "Gv" $ [stamp s, int a, eqprop e, 
                                            tyckind k, ipath p])
	  end

      | tycon (T.DEFtyc{stamp=x, tyfun=T.TYFUN{arity=r,body=b},
			strict=s, path=p}) () =
        W.identify(MIkey(MI.TYCid x))
	  (fn()=> "Dw" $ [stamp x, int r, ty b, list bool s, ipath p])

      | tycon (T.PATHtyc{arity=a, entPath=e, path=p}) () =
          "Pw" $ [int a, entPath e, ipath p]
(*
	  W.identify(EPkey e)
	  (fn()=>"Pw" $ [int a, entPath e, ipath p])
*)

      | tycon (T.RECORDtyc l) () = "Rw" $ [list label l]
      | tycon (T.RECtyc i) () = "Cw" $ [int i]
      | tycon T.ERRORtyc () = "Ew" $ []

    and ty (T.VARty(ref(T.INSTANTIATED t))) () = ty t ()
      | ty (T.VARty(ref(T.OPEN _))) () = (* "Vx" $ [tyvar v] *)
  	  bug "uninstatiated VARty in pickmod" 
      | ty (T.CONty (c,[])) () = "Nx" $ [tycon c]
      | ty (T.CONty (c,l)) () = "Cx" $ [tycon c, list ty l]
      | ty (T.IBOUND i) () = "Ix" $ [int i]
      | ty T.WILDCARDty () = "Wx" $ []
      | ty (T.POLYty{sign=s,tyfun=T.TYFUN{arity=r,body=b}}) () = 
	  "Px" $ [list bool s, int r, ty b]
      | ty T.UNDEFty () = "Ux" $ []
      | ty _ () = bug "unexpected types in pickmod-ty"

    fun inl_info (II.INL_PRIM(p, t)) () = "Py" $ [primop p, option ty t]
      | inl_info (II.INL_STR sl) () = "Sy" $ [list inl_info sl]
      | inl_info (II.INL_NO) () = "Ny" $ []
      | inl_info _ () = bug "unexpected inl_info in pickmod"

    fun var (V.VALvar{access=a, info=z, path=p, typ=ref t}) () =
	  "Vz" $ [access a, inl_info z, spath p, ty t]
      | var (V.OVLDvar{name=n, options=ref p, 
                       scheme=T.TYFUN{arity=r,body=b}}) () =
          "Oz" $ [symbol n, list overld p, int r, ty b]
      | var  V.ERRORvar () = "Ez" $ []

    and overld {indicator=i,variant=v} () = "OA" $ [ty i, var v]

    fun fsigId(M.FSIG{kind,
		      paramsig=p as M.SIG{stamp=ps,...},
		      paramvar=q,
		      paramsym=s,
		      bodysig=b as M.SIG{stamp=bs,...}}) =
	  MI.FSIGid{paramsig=ps,bodysig=bs}
      | fsigId _ = bug "unexpected functor signatures in fsigId"


    fun strDef(M.CONSTstrDef s) () = "CE" $ [Structure s]
      | strDef(M.VARstrDef(s,p)) () = "VE" $ [Signature s,entPath p]

    (* 
     * boundeps is not pickled right now, but it really should
     * be pickled in the future.
     *)
    and Signature (M.SIG{name=k, closed=c, fctflag=f, 
                         stamp=m, symbols=l, elements=e, 
                         boundeps=ref b, lambdaty=_, typsharing=t, 
                         strsharing=s}) () =
	 let val id = MI.SIGid m
	  in W.identify (MIkey id)
	      (fn () => 
                case (SCStaticEnv.lookSIG context0 id)
		 of SOME _ => "XE" $ [modId id]
		  | NONE => "SE" $ [option symbol k, bool c, bool f,
                                    stamp m, list symbol l,
				    list (tuple2 (symbol,spec)) e,

(* this is currently turned off ...
 *                              option (list (tuple2 (entPath, tkind))) b, 
 *)
                                option (list (tuple2 (entPath, tkind))) NONE,
			        list (list spath) t, 
				list (list spath) s])
	 end

      | Signature M.ERRORsig () = "EE" $ []

    and fctSig (fs as M.FSIG{kind=k, paramsig=p, paramvar=q, 
			     paramsym=s, bodysig=b}) () =
	  let val id = fsigId fs
	   in W.identify (MIkey id)
		    (fn () => 
                      case SCStaticEnv.lookFSIG context0 id
		       of SOME _ => "XF" $ [modId id]
		        | NONE => "FF" $ [option symbol k, Signature p, 
                                          entVar q, option symbol s, 
                                          Signature b])
	  end
      | fctSig M.ERRORfsig () = "EF" $ []

    and spec (M.TYCspec{spec=t, entVar=v, scope=s}) () =
	  "TG" $ [tycon t,entVar v,int s]
      | spec (M.STRspec{sign=s, slot=d, def=e, entVar=v}) () =
	  "SG" $ [Signature s, int d, option (tuple2 (strDef, int)) e, entVar v]
      | spec (M.FCTspec{sign=s, slot=d, entVar=v}) () =
	  "FG" $ [fctSig s, int d, entVar v]
      | spec (M.VALspec{spec=t, slot=d}) () = "PH" $ [ty t, int d]
      | spec (M.CONspec{spec=c, slot=i}) () = "QH" $ [datacon c, option int i]

    and entity (M.TYCent t) () = "LI" $ [tycEntity t]
      | entity (M.STRent t) () = "SI" $ [strEntity t]
      | entity (M.FCTent t) () = "FI" $ [fctEntity t]
      | entity M.ERRORent () = "EI" $ []

    and fctClosure (M.CLOSURE{param=p,body=s,env=e}) () =
	  "FJ" $ [entVar p, strExp s, entityEnv e]

    and Structure (m as M.STR{sign=s as M.SIG{stamp=g,...},
			      rlzn=r as {stamp=st,...},
			      access=a, info=z}) () = 
	  let val id = MI.STRid{rlzn=st,sign=g}
	   in W.identify (MIkey id)
	      (fn () => 
                case SCStaticEnv.lookSTR context0 id
		  of NONE  => 
		      ((* if isGlobalStamp st andalso isGlobalStamp g
		       then say (String.concat["#pickmod: missed global structure ",
					       MI.idToString id, "\n"])
		       else (); *)
		       "SK" $ [Signature s, strEntity r, 
			       access a, inl_info z])
                   | SOME _ => "XK" $ [modId id, access a])
	  end
      | Structure (M.STRSIG{sign=s,entPath=p}) () = 
          "GK" $ [Signature s, entPath p]
      | Structure M.ERRORstr () = "EK" $ []
      | Structure _ () = bug "unexpected structure in Structure"

    and Functor (M.FCT{sign=s, rlzn=r as {stamp=m,...}, 
                       access=a, info=z}) () = 
	  let val sigid = fsigId s
	      val id = MI.FCTid{rlzn=m, sign=sigid}
	   in W.identify (MIkey id)
	      (fn () =>
                case SCStaticEnv.lookFCT context0 id
		  of NONE =>
		      ((* if isGlobalStamp m andalso 
			  (case sigid
			     of MI.FSIGid{paramsig,bodysig} => 
				 isGlobalStamp paramsig andalso
				 isGlobalStamp bodysig
                              | _ => (say "#pickmod: funny functor sig id\n";
				      false))
		       then say (String.concat["#pickmod: missed global functor ",
					       MI.idToString id, "\n"])
		       else (); *)
		       "FL" $ [fctSig s, fctEntity r, 
			       access a, inl_info z])
                   | SOME _ => "XL" $ [modId id, access a])
	  end
      | Functor M.ERRORfct () = "EL" $ []

    and stampExp (M.CONST s) () = "CM" $ [stamp s]
      | stampExp (M.GETSTAMP s) () = "GM" $ [strExp s]
      | stampExp M.NEW () = "NM" $ []

    and tycExp (M.CONSTtyc t) () = "CN" $ [tycon t]
      | tycExp (M.FMGENtyc (t,evOp)) () = "GN" $ [tycon t, option entVar evOp]
      | tycExp (M.FMDEFtyc t) () = "DN" $ [tycon t]
      | tycExp (M.VARtyc s) () = "VN" $ [entPath s]

    and strExp (M.VARstr s) () = "VO" $ [entPath s]
      | strExp (M.CONSTstr s) () = "CO" $ [strEntity s]
      | strExp (M.STRUCTURE{stamp=s,entDec=e}) () = 
	  "SO" $ [stampExp s, entityDec e]
      | strExp (M.APPLY(f,s)) () = "AO" $ [fctExp f, strExp s]
      | strExp (M.LETstr(e,s)) () = "LO" $ [entityDec e, strExp s]
      | strExp (M.ABSstr(s,e)) () = "BO" $ [Signature s, strExp e]
      | strExp (M.CONSTRAINstr{boundvar,raw,coercion}) () =
	  "RO" $ [entVar boundvar, strExp raw, strExp coercion] 
      | strExp (M.FORMstr fs) () = "FO" $ [fctSig fs]

    and fctExp (M.VARfct s) () = "VP" $ [entPath s]
      | fctExp (M.CONSTfct e) () = "CP" $ [fctEntity e]
      | fctExp (M.LAMBDA{param=p,body=b}) () = "LP" $ [entVar p, strExp b]
      | fctExp (M.LAMBDA_TP{param=p, body=b, sign=fs}) () = 
                 "PP" $ [entVar p, strExp b, fctSig fs]
      | fctExp (M.LETfct(e,f)) () = "TP" $ [entityDec e, fctExp f]

    and entityExp (M.TYCexp t) () = "TQ" $ [tycExp t]
      | entityExp (M.STRexp t) () = "SQ" $ [strExp t]
      | entityExp (M.FCTexp t) () = "FQ" $ [fctExp t]
      | entityExp (M.ERRORexp) () = "EQ" $ []
      | entityExp (M.DUMMYexp) () = "DQ" $ []

    and entityDec (M.TYCdec(s,x)) () = "TR" $ [entVar s, tycExp x]
      | entityDec (M.STRdec(s,x,n)) () = "SR" $ [entVar s, strExp x, symbol n]
      | entityDec (M.FCTdec(s,x)) () = "FR" $ [entVar s, fctExp x]
      | entityDec (M.SEQdec e) () = "QR" $ [list entityDec e]
      | entityDec (M.LOCALdec(a,b)) () = "LR" $ [entityDec a, entityDec b]
      | entityDec M.ERRORdec () = "ER" $ []
      | entityDec M.EMPTYdec () = "MR" $ []

    and entityEnv (M.MARKeenv(s,r)) () = 
	  let val id = MI.EENVid s
	   in W.identify(MIkey id)
	      (fn() => case SCStaticEnv.lookEENV context0 id
		        of SOME _ => "X4" $ [modId id]
		         | NONE => "M4" $ [stamp s, entityEnv r])
          end
      | entityEnv (M.BINDeenv(d, r)) () = 
	  "B4" $ [list (tuple2(entVar, entity)) (ED.members d), entityEnv r]
      | entityEnv M.NILeenv () = "N4" $ []
      | entityEnv M.ERReenv () = "E4" $ []

    and strEntity {stamp=s, entities=e, lambdaty=_, rpath=r} () =
	  "SS" $ [stamp s, entityEnv e, ipath r]

    and fctEntity {stamp=s, closure=c, lambdaty=_,
                   tycpath=_, rpath=r} () =
  	  "FT" $ [stamp s, fctClosure c, ipath r] 
(*      | fctEntity {stamp=s, closure=c, lambdaty=ref t, 
                   tycpath=SOME _, rpath=r} () =
          bug "unexpected fctEntity in pickmod"
*)

    and tycEntity x () = tycon x ()

    fun fixity Fixity.NONfix () = "NW" $ [] 
      | fixity (Fixity.INfix(i,j)) () = "IW" $ [int i, int j]

    fun binding (B.VALbind x) () = "V2" $ [var x]
      | binding (B.CONbind x) () = "C2" $ [datacon x]
      | binding (B.TYCbind x) () = "T2" $ [tycon x]
      | binding (B.SIGbind x) () = "G2" $ [Signature x]
      | binding (B.STRbind x) () = "S2" $ [Structure x]
      | binding (B.FSGbind x) () = "I2" $ [fctSig x]
      | binding (B.FCTbind x) () = "F2" $ [Functor x]
      | binding (B.FIXbind x) () = "X2" $ [fixity x]

    fun env alpha e () = 
	let fun uniq (a::b::rest) = if S.eq(a,b) then uniq(b::rest)
				    else a::uniq(b::rest)
	      | uniq l = l
	    val syms = uniq(Sort.sort S.symbolGt (Env.symbols e))
	    val pairs = map (fn s => (s, Env.look(e,s))) syms
	 in "E3" $ [list (tuple2(symbol,alpha)) pairs]
	end

    val pickle = W.pickle (env binding e0)

    val hash = pickle2hash pickle

    val exportLvars = rev(!lvlist)
    val exportPid = case exportLvars of [] => NONE
                                      | _ => SOME hash

 in addPickles (Word8Vector.length pickle);
    {hash = hash,
     pickle = pickle,
     exportLvars = exportLvars,
     exportPid = exportPid}
end (* fun pickleEnv *)

fun dontPickle (senv : StaticEnv.staticEnv, count) =
    let val hash =
	    let val toByte = Word8.fromLargeWord o Word32.toLargeWord
		val >> = Word32.>>
		infix >>
		val w = Word32.fromInt count
	    in
	      PersStamps.fromBytes(
	      Word8Vector.fromList
	       [0w0,0w0,0w0,toByte(w >> 0w24),0w0,0w0,0w0,toByte(w >> 0w16),
		0w0,0w0,0w0,toByte(w >> 0w8),0w0,0w0,0w0,toByte(w)])
	    end
	fun uniq (a::b::rest) = if S.eq(a,b) then uniq(b::rest)
				else a::uniq(b::rest)
	  | uniq l = l
        (* next two lines are alternative to using Env.consolidate *)
	val syms = uniq(Sort.sort S.symbolGt (Env.symbols senv))
	fun newAccess i = A.PATH (A.EXTERN hash, i)
	fun mapbinding(sym,(i,env,lvars)) =
	    case Env.look(senv,sym)
	      of B.VALbind(V.VALvar{access=a, info=z, path=p, typ=ref t}) =>
		  (case a
		    of A.LVAR k => 
			(i+1,
			 Env.bind(sym,B.VALbind(V.VALvar{access=newAccess i,
							 info=z, path=p,
							 typ=ref t}),
				  env),
			 k :: lvars)
		     | _ => (say(A.prAcc a ^ "\n"); bug "dontPickle 1"))
	       | B.STRbind(M.STR{sign=s, rlzn=r, access=a, info=z}) =>
		  (case a
		    of A.LVAR k => 
			(i+1,
			 Env.bind(sym,B.STRbind(M.STR{access=newAccess i,
						      sign=s,rlzn=r,info=z}),
				  env),
			 k :: lvars)
		     | _ => (say(A.prAcc a ^ "\n"); bug "dontPickle 2"))
	       | B.FCTbind(M.FCT{sign=s, rlzn=r, access=a, info=z}) =>
		  (case a
		    of A.LVAR k => 
			(i+1,
			 Env.bind(sym,B.FCTbind(M.FCT{access=newAccess i,
						      sign=s,rlzn=r,info=z}),
				  env),
			 k :: lvars)
		     | _ => (say(A.prAcc a ^ "\n"); bug "dontPickle 3"))
	       | B.CONbind(T.DATACON{name=n,const=c,typ=t,sign=s,
				     rep as (A.EXNFUN a | A.EXNCONST a)}) =>
		   let val newrep =
		           case rep
			     of A.EXNFUN a => A.EXNFUN(newAccess i)
			      | A.EXNCONST a => A.EXNCONST(newAccess i)
                    in case a
			 of A.LVAR k =>
			     (i+1,
			      Env.bind(sym,B.CONbind
				       (T.DATACON{rep=newrep, name=n,
						  const=c, typ=t, sign=s}),
				       env),
			      k :: lvars)
			  | _ => (say(A.prAcc a ^ "\n"); bug "dontPickle 4")
		   end
	       | binding => 
		   (i, Env.bind(sym,binding,env), lvars)
	val (_,newenv,lvars) = foldl mapbinding (0,StaticEnv.empty,nil) syms
	val exportPid = case lvars
			  of [] => NONE
			   | _ => SOME hash
     in (newenv,hash,rev(lvars),exportPid)
    end

end (* toplevel local *)
end (* structure PickMod *)


(*
 * $Log: pickmod.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:47  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.17  1998/01/29 21:40:45  jhr
 *   Implement isolate as a primop to make sure that it indeed
 *   achieve the intended effect (i.e., forgetting the current
 *   stack). [zsh]
 *
 * Revision 1.16  1997/10/28 20:17:50  dbm
 *   No longer put lambdaty's into pickles of environments.
 *   They will have to be recomputed by transmodules; but this is fine
 *   (and may be faster than pickling and unpickling).
 *   Warning: if the two rlzn's can have the same stamp and same entityEnv
 *    but different lambdaty's, this can cause unwanted sharing of
 *    lty refs.  But Dave says this is impossible.  -- Andrew
 *
 * Revision 1.15  1997/10/19  23:51:54  dbm
 *   To fix the space blowup of bug 1297, we make sure that entries in
 *   the ltys set are unique in the pickling of lambda types.  This fixes
 *   a bug where a single structure was getting multiple representations
 *   that differed only in the numbering of lambda type variables.  We use
 *   BinaryDict for the collection.
 *
 * Revision 1.14  1997/09/30  02:33:18  dbm
 *   New constructor ERReenv of entityEnv.
 *
 * Revision 1.13  1997/09/17  21:33:55  dbm
 *   New symbol parameter for STRdec.
 *
 * Revision 1.12  1997/08/22  18:35:05  george
 *    Add the fctflag field to the signature datatype -- zsh
 *
 * Revision 1.10  1997/07/15  16:16:54  dbm
 *   Adjust to changes in signature representation.
 *
 * Revision 1.9  1997/05/20  12:26:32  dbm
 *   SML '97 sharing, where structure.
 *
 * Revision 1.8  1997/05/05  19:55:07  george
 *    Turning off some measurement hooks - zsh
 *
 * Revision 1.7  1997/04/18  15:48:46  george
 *   Cosmetic changes on some constructor names. Changed the shape for
 *   FIX type to potentially support shared dtsig. -- zsh
 *
 * Revision 1.6  1997/04/02  04:12:32  dbm
 *   Added CONSTRAINstr to type strExp.  Fix for bug 12.
 *
 * Revision 1.5  1997/03/25  13:41:27  george
 *   Fixing the coredump bug caused by duplicate top-level declarations.
 *   For example, in almost any versions of SML/NJ, typing
 *           val x = "" val x = 3
 *   would lead to core dump. This is avoided by changing the "exportLexp"
 *   field returned by the pickling function (pickle/picklemod.sml) into
 *   a list of lambdavars, and then during the pretty-printing (print/ppdec.sml),
 *   each variable declaration is checked to see if it is in the "exportLvars"
 *   list, if true, it will be printed as usual, otherwise, the pretty-printer
 *   will print the result as <hiddle-value>.
 * 						-- zsh
 *
 * Revision 1.4  1997/03/17  18:58:05  dbm
 * Changes in datatype representation to support datatype replication.
 *
 * Revision 1.3  1997/02/26  21:52:21  george
 *    Turn off the sharing of the structure bindings, because structures
 *    with same modids may potentially have different dynamic accesses.
 *    This fixed BUG 1144 reported by Elsa Gunter.
 *
 *)
