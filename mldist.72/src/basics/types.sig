(* Copyright 1989 by AT&T Bell Laboratories *)
(* types.sig *)

signature TYPES =
sig

    type tycpos
    type polysign (* = {weakness: int, eq: bool} list *)
    type label (* = symbol *)

    (* absfbpos (abstracted functor body position): where to find
       a type constructor or structure when instantiating a functor body.
       It's either in the parameter or in a sequence of types defined
       or generated by the functor body.

       The list for the PARAM variant is the path through the structure
       instantiation arrays.  For type constructors, the final element is
       the position in a type instantiation array.   A nil list for the PARAM
        variant is used to return the entire parameter structure; it is not
        a valid path for a type constructor.*)
        
    datatype absfbpos = PARAM of int list
	              | SEQ of int

    datatype eqprop = YES | NO | IND | OBJ | DATA | UNDEF

    val infinity : int

    type tyvar  (* = tvkind ref *)

    datatype tvkind      (* type variable kinds *)
      = IBOUND of int	 (* inferred bound type variables -- indexed *) 
      | META of	         (* metavariables -- depth < infinity for lambda bound *)
	  {depth: int,
	   weakness: int,
	   eq: bool}
      | INSTANTIATED of ty
      | UBOUND of        (* user bound type variables -- user name *)
	  {name: Symbol.symbol,
	   depth : int,
	   weakness: int,
	   eq: bool}

    and datacon  (* exceptions are a special case with rep=VARIABLE() *)
      = DATACON of
	  {name  : Symbol.symbol,
	   const : bool,
	   typ   : ty,
	   rep   : Access.conrep,
	   sign  : Access.conrep list}

    and tyckind
      = PRIMtyc  		     (* primitive type constructors like int *)
      | ABStyc of tycon	     (* abstract type constructors formed by abstype *)
      | DATAtyc of datacon list      (* datatype constructors *)
      | FORMtyck

    and tycon
      = GENtyc of {stamp : Stamps.stamp, 
		   arity : int, 
		   eq    : eqprop ref,
		   path  : Symbol.symbol list,
		   kind	 : tyckind ref}
      | DEFtyc of {path : Symbol.symbol list,
		   tyfun : tyfun}
      | RECORDtyc of label list
      | FORMtyc of {pos : int, spec : tycon}
      | RELtyc of  {pos : tycpos, name : Symbol.symbol list}
      | ABSFBtyc of absfbpos
      | NULLtyc
      | ERRORtyc
 
    and ty 
      = VARty of tyvar
      | CONty of tycon * ty list
      | FLEXRECORDty of rowty ref
      | POLYty of {sign: {weakness:int, eq:bool} list, tyfun: tyfun, abs: int}
      | UNDEFty
      | ERRORty

    and rowty
      = OPEN of (label * ty) list
      | CLOSED of ty

    and tyfun
      = TYFUN of
          {arity : int,
	   body : ty}

    val mkTyvar   : tvkind -> tyvar
    val bogusCON : datacon
    val bogusEXN : datacon

end (* signature TYPES *)
