(* Copyright 1989 by AT&T Bell Laboratories *)
(* importer.sig: this is all the Interact functor needs from the import
   mechanism. *)

signature IMPORTER =
   sig
      exception Import (* Raised for any sensible failure to import. *)
      val getAndExecModule: Modules.env -> string -> Modules.env
      val compiling'env: Modules.env ref
   end
