(* pack-word-b32.sml
 *
 * COPYRIGHT (c) 1995 AT&T Bell Laboratories.
 *
 * This is the non-native implementation of 32-bit big-endian packing
 * operations.
 *
 *)

structure Pack32Big : PACK_WORD =
  struct
    structure W = LargeWord
    structure W8 = Word8
    structure W8V = InlineT.Word8Vector
    structure W8A = InlineT.Word8Array

    val bytesPerElem = 4
    val isBigEndian = true

  (* convert the byte length into word32 length (n div 4), and check the index *)
    fun chkIndex (len, i) = let
	  val len = Word.toIntX(Word.>>(Word.fromInt len, 0w2))
	  in
	    if (InlineT.DfltInt.ltu(i, len)) then () else raise Subscript
	  end

    fun mkWord (b1, b2, b3, b4) =
	  W.orb (W.<<(Word8.toLargeWord b1, 0w24),
	  W.orb (W.<<(Word8.toLargeWord b2, 0w16),
	  W.orb (W.<<(Word8.toLargeWord b3,  0w8),
		      Word8.toLargeWord b4)))

    fun subVec (vec, i) = let
	  val _ = chkIndex (W8V.length vec, i)
	  val k = Word.toIntX(Word.<<(Word.fromInt i, 0w2))
	  in
	    mkWord (W8V.sub(vec, k), W8V.sub(vec, k+1),
	      W8V.sub(vec, k+2), W8V.sub(vec, k+3))
	  end
  (* since LargeWord is 32-bits, no sign extension is required *)
    fun subVecX(vec, i) = subVec (vec, i)

    fun subArr (arr, i) = let
	  val _ = chkIndex (W8A.length arr, i)
	  val k = Word.toIntX(Word.<<(Word.fromInt i, 0w2))
	  in
	    mkWord (W8A.sub(arr, k), W8A.sub(arr, k+1),
	      W8A.sub(arr, k+2), W8A.sub(arr, k+3))
	  end
  (* since LargeWord is 32-bits, no sign extension is required *)
    fun subArrX(arr, i) = subArr (arr, i)

    fun update (arr, i, w) = let
	  val _ = chkIndex (W8A.length arr, i)
	  val k = Word.toIntX(Word.<<(Word.fromInt i, 0w2))
	  in
	    W8A.update (arr, k,   W8.fromLargeWord(W.>>(w, 0w24)));
	    W8A.update (arr, k+1, W8.fromLargeWord(W.>>(w, 0w16)));
	    W8A.update (arr, k+2, W8.fromLargeWord(W.>>(w,  0w8)));
	    W8A.update (arr, k+3, W8.fromLargeWord w)
	  end

  end;


(*
 * $Log: pack-word-b32.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:38  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.1.1.1  1997/01/14 01:38:16  george
 *   Version 109.24
 *
 *)
