(* unix-sig.sml
 *
 * COPYRIGHT (c) 1995 AT&T Bell Laboratories.
 *
 *)

signature UNIX =
  sig
    type proc

      (* executeInEnv (path, args, env)
       *   forks/execs new process given by path
       *   The new process will have environment env, and
       *   arguments args prepended by the last arc in path
       *   (following the Unix convention that the first argument
       *   is the command name).
       *   Returns an abstract type proc, which represents
       *   the child process plus streams attached to the
       *   the child process stdin/stdout.
       *
       *   Simple command searching can be obtained by using
       *     executeInEnv ("/bin/sh", "-c"::args, env)
       *)
    val executeInEnv : string * string list * string list -> proc

      (* execute (path, args) 
       *       = executeInEnv (path, args, Posix.ProcEnv.environ())
       *)
    val execute : string * string list -> proc

      (* streamsOf proc
       * returns an instream and outstream used to read
       * from and write to the stdout and stdin of the 
       * executed process.
       *
       * The underlying files are set to be close-on-exec.
       *)
    val streamsOf : proc -> TextIO.instream * TextIO.outstream

      (* reap proc
       * This closes the associated streams and waits for the
       * child process to finish, returns its exit status.
       *
       * Note that even if the child process has already exited,
       * so that reap returns immediately,
       * the parent process should eventually reap it. Otherwise,
       * the process will remain a zombie and take a slot in the
       * process table.
       *)
    val reap : proc -> Posix.Process.exit_status

      (* kill (proc, signal)
       * sends the Posix signal to the associated process.
       *)
    val kill : proc * Posix.Signal.signal -> unit

  end


(*
 * $Log: unix-sig.sml,v $
 * Revision 1.1.1.1  1999/12/03 19:59:42  dbm
 * Import of 110.0.6 src
 *
 * Revision 1.1.1.1  1997/01/14 01:38:25  george
 *   Version 109.24
 *
 *)
