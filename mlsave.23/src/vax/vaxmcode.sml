structure VaxMCode : VAXCODER = struct

structure B : BASICVAX = BasicVax
open B

val offset = ref 0

datatype Register = reg of int

val r0 = reg 0
val r1 = reg 1
val r2 = reg 2
val r3 = reg 3
val r4 = reg 4
val r5 = reg 5
val r6 = reg 6
val r7 = reg 7
val r8 = reg 8
val r9 = reg 9
val r10 = reg 10
val r11 = reg 11
val r12 = reg 12
val r13 = reg 13
val sp = reg 14
val pc = reg 15

datatype EA = direct of Register
	    | autoinc of Register
	    | autodec of Register
	    | displace of int * Register
	    | deferred of int * Register
	    | immed of int
	    | immedlab of Label
	    | address of Label
	    | index of EA * Register

fun emitstring s =
	let val len = String.length s   (* bug .. shouldn't need 'String.' *)
	    fun emits i = if i < len then (emitbyte(ordof(s,i)); emits (i+1))
			  else ()
	in  emits 0
	end

(* This is identical to M68PrimReal except that emitword is different,
   and the bias is off by two. *)
structure VaxPrimReal : PRIMREAL =
struct
open BitOps
val significant = 53 (* 52 + redundant 1/2 bit *)
fun outofrange s = ErrorMsg.complain("Real constant "^s^" out of range")
(* Convert a portion of a boolean array to the appropriate integer. *)
exception Bits
fun bits(a,start,width) =
    let fun b true = 1
	  | b false = 0
	fun f 0 = b (a sub start)
	  | f n = b (a sub (start+n)) + 2 * f(n-1)
    in  if length a < start+width orelse start < 0 orelse width < 0
	then raise Bits
	else f (width-1)
    end
fun emitreal (sign,frac,exp) =
    let val exponent = exp + 1024
	fun emit () =
	    let val word0 = case frac sub 0 of (* zero? *)
				true => sign<<15 bit_or exponent<<4 bit_or
					     bits(frac,1,4)
			      | false => 0
		val word1 = bits(frac,5,16)
		val word2 = bits(frac,21,16)
		val word3 = bits(frac,37,16)
	    in  B.emitword word0;
		B.emitword word1;
		B.emitword word2;
		B.emitword word3
	    end
    in  if exponent < 1 orelse exponent > 2047
	then outofrange "" (* A hack *)
	else emit()
    end
end
structure VaxRealConst = RealConst(VaxPrimReal)
open VaxRealConst

fun regmode(mode,r) = emitbyte(mode*16+r)

fun emitarg (direct(reg r)) = regmode(5,r)
  | emitarg (autoinc(reg r)) = regmode(8,r)
  | emitarg (autodec(reg r)) = regmode(7,r)
  | emitarg (immed i) = 
	if i>=0 andalso i<64 then emitbyte i
	    else (emitarg(autoinc pc); emitlong i)
  | emitarg (displace(i,reg r)) =
	 if i=0 then regmode(6,r)
	 else (case intsize i 
		 of  1 => (regmode(10,r); signedbyte i)
		   | 2 => (regmode(12,r); emitword i)
		   | 4 => (regmode(14,r); emitlong i))
  | emitarg (deferred(i,reg r)) =
	(case intsize i of
	     1 => (regmode(11,r); signedbyte i)
	   | 2 => (regmode(13,r); emitword i)
	   | 4 => (regmode(15,r); emitlong i))
  | emitarg (index(ea, reg r)) = (regmode(4,r); emitarg ea)
  | emitarg (address lab) = jump(MODE,lab) (* no good for branches *)

fun emit2arg (arg1,arg2) = (emitarg arg1; emitarg arg2)

fun emit3arg (arg1,arg2,arg3) = (emitarg arg1; emitarg arg2; emitarg arg3)

fun pure (autoinc _) = false
  | pure (autodec _) = false
  | pure _ = true

fun args23(f2,f3) (args as (a,b,c)) = 
	if b=c andalso pure b then (f2(a,b)) else f3 args

fun immedbyte(i) =
	if i>=0 andalso i<64 then emitbyte i
	    else (emitarg(autoinc pc); signedbyte i);

fun immedword(i) =
	if i>=0 andalso i<64 then emitbyte i
	    else (emitarg(autoinc pc); emitword i);

fun emitlab (i,lab) = jump(LABPTR i, lab)

fun jbr (address lab) = jump(JBR,lab)
fun bbc (immed 0, arg, address lab) =
	    let val r = (ref 0, 14*16+9,14*16+8)
	     in jump(WHICH r, lab); emitarg arg; jump(COND r, lab)
	    end
  | bbc (arg1, arg2, address lab) =
	    let val r = (ref 0, 14*16+1,14*16+0)
	     in jump(WHICH r, lab); emitarg arg1; emitarg arg2; jump(COND r, lab)
	    end
fun bbs (immed 0, arg, address lab) =
	    let val r = (ref 0, 14*16+8,14*16+9)
	     in jump(WHICH r, lab); emitarg arg; jump(COND r, lab)
	    end
  | bbs (arg1, arg2, address lab) =
	    let val r = (ref 0, 14*16+0,14*16+1)
	     in jump(WHICH r, lab); emitarg arg1; emitarg arg2; jump(COND r, lab)
	    end

fun movb (immed i, arg2) = (emitbyte(9*16); immedbyte i; emitarg arg2)
  | movb args = (emitbyte (9*16); emit2arg args)

fun movzbl args = (emitbyte (9*16+10); emit2arg args)

fun pushal args = (emitbyte (13*16+15); emitarg args)

fun addl2 (immed 1, arg) = (emitbyte(13*16+6); emitarg arg)
  | addl2 args = (emitbyte (12*16); emit2arg args)

fun moval (arg, autodec(reg 14)) = pushal arg
  | moval (args as (displace(i, reg p),direct (reg q))) =
	    if p=q andalso i> ~128 andalso i < 128
		then addl2(immed i, direct(reg p))
	        else (emitbyte (13*16+14); emit2arg args)
  | moval args = (emitbyte (13*16+14); emit2arg args)

fun movl (immedlab l, arg) = moval(address l, arg)
  | movl (arg, autodec(reg 14)) = (emitbyte(13*16+13); emitarg arg)
  | movl (immed 0, arg) = (emitbyte(13*16+4); emitarg arg)
  | movl args = (emitbyte (13*16); emit2arg args)

fun rsb () = emitbyte 5
fun cmpl args = (emitbyte (13*16+1); emit2arg args)
fun addl3 args = (emitbyte (12*16+1); emit3arg args)
val addl3 = args23 (addl2,addl3)
fun subl2 args = (emitbyte (12*16+2); emit2arg args)
fun subl3 args = (emitbyte (12*16+3); emit3arg args)
val subl3 = args23 (subl2,subl3)
fun bisl3 args = (emitbyte (12*16+9); emit3arg args)
fun ashl (immed i,arg2,arg3) =
	(emitbyte (7*16+8);
	 immedbyte i;
	 emitarg arg2;
	 emitarg arg3)
fun mull2 args = (emitbyte (12*16+4); emit2arg args)
fun divl3 args = (emitbyte (12*16+7); emit3arg args)
fun divl2 args = (emitbyte (12*16+6); emit2arg args)
val divl3 = args23 (divl2,divl3)
fun jmp (arg as address lab) = jbr arg
  | jmp arg = (emitbyte (16+7); emitarg arg)
fun brb (displace(i,reg 15)) = (emitbyte (16+1); signedbyte i)
fun brw (displace(i,reg 15)) = (emitbyte (3*16+1); emitword i)

local fun condj(i,j) =
	fn (address lab) => let val r = (ref 0,16+i,16+j)
		             in jump(WHICH r, lab); jump(COND r, lab)
		            end
	 | displace(k, reg 15) => (emitbyte (16+i); signedbyte k)
 in val beql = condj(3,2)
    val bneq = condj(2,3)
    val jne = bneq
    val bgeq = condj(8,9)
    val bgtr = condj(4,5)
    val blss = condj(9,8)
    val bleq = condj(5,4)
end
fun sobgeq (arg,address lab) = (emitbyte (15*16+4); emitarg arg;
				jump(BYTEDISPL,lab))

fun movg args = (emitword(20733); emit2arg args)
fun mnegg args = (emitword(21245); emit2arg args)
fun addg3 args = (emitword(16893); emit3arg args)
fun subg3 args = (emitword(17405); emit3arg args)
fun mulg3 args = (emitword(17917); emit3arg args)
fun divg3 args = (emitword(18429); emit3arg args)
fun cmpg args = (emitword(20989); emit2arg args)

fun push arg = movl(arg,autodec sp)
fun pusha arg = pushal arg
fun pop arg = movl(autoinc sp,arg)

fun comment _ = ()

end (* structure MCode *)