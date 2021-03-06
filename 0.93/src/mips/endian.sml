(* Copyright 1991 by AT&T Bell Laboratories *)
structure LittleEndian : ENDIAN = 
    struct
	val >> = Bits.rshift
	val &  = Bits.andb
	infix >> &

	val order_real = implode o rev o explode
	val low_order_offset = 0
	fun wordLayout (hi,lo) =
	      (lo & 255, (lo >> 8) & 255, hi & 255, (hi >> 8) & 255)
    end

structure BigEndian : ENDIAN = 
    struct
	val >> = Bits.rshift
	val &  = Bits.andb
	infix >> &

	fun order_real x = x
	val low_order_offset = 1
	fun wordLayout (hi,lo) =
	      ((hi >> 8) & 255, hi & 255, (lo >> 8) & 255, lo & 255)
    end

