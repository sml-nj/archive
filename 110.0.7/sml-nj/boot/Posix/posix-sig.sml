(* posix-sig.sml
 *
 * COPYRIGHT (c) 1995 AT&T Bell Laboratories.
 *
 * Signature for POSIX 1003.1 binding
 *
 *)

signature POSIX =
  sig

    structure Error   : POSIX_ERROR
    structure Signal  : POSIX_SIGNAL
    structure Process : POSIX_PROCESS
    structure ProcEnv : POSIX_PROC_ENV
    structure FileSys : POSIX_FILE_SYS
    structure IO      : POSIX_IO
    structure SysDB   : POSIX_SYS_DB
    structure TTY     : POSIX_TTY

    sharing type Process.pid = ProcEnv.pid = TTY.pid
        and type Process.signal = Signal.signal
        and type ProcEnv.file_desc = FileSys.file_desc = TTY.file_desc
        and type FileSys.open_mode = IO.open_mode
        and type ProcEnv.uid = FileSys.uid = SysDB.uid
        and type ProcEnv.gid = FileSys.gid = SysDB.gid

  end (* signature POSIX *)

(*
 * $Log: posix-sig.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:41  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.3  1997/06/07 15:27:42  jhr
 *   SML'97 Basis Library changes (phase 3; Posix changes)
 *
 * Revision 1.2  1997/05/20  12:15:50  dbm
 *   SML '97 sharing, where structure.
 *
 * Revision 1.1.1.1  1997/01/14  01:38:23  george
 *   Version 109.24
 *
 *)
