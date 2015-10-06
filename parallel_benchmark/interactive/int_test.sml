open LamIFut

(* val fork = MLton.Parallel.ForkJoin.fork *)

val stdin = ref (TextIO.getInstream TextIO.stdIn)

fun inputLine () =
    let fun iL_int line =
            case IO.input1 (!stdin) of
                NONE => NONE
              | SOME (c, is') =>
                (stdin := is';
                 if c = #"\n" then
                     SOME line
                 else
                     iL_int (line ^ (str c)))
    in
        iL_int ""
    end

val proc_std_in =
    let fun proc_std_in_gen () =
            ((* print "What is your name? "; *)
             case inputLine () of
                 NONE => OS.Process.exit OS.Process.success
               | SOME l =>
                 (print "Processed\n";
                  ("Hi, " ^ l ^ "\n", eftr "proc_std_in" proc_std_in_gen)))
    in
        eftr "proc_std_in" proc_std_in_gen
    end

val fibs =
    let fun fib n =
            if n <= 1 then 1
            else
                let
                    val fork = if n <= 20 then
                                   (fn (f1, f2) => (f1 (), f2 ()))
                               else
                                   MLton.Parallel.ForkJoin.fork
                    val (a, b) = fork (fn () => fib (n - 1),
                                       fn () => fib (n - 2))
                in
                    (a + b)
                    handle Overflow =>
                           OS.Process.exit OS.Process.success
                end
        fun fibs_gen n () =
            ((* print ("fib(" ^ (Int.toString n) ^ ")"); *)
            (("fib(" ^ (Int.toString n) ^ ") = " ^ Int.toString (fib n)) ^ "\n",
             eftr "fibs" (fibs_gen (n + 1))))
    in
        eftr "fibs" (fibs_gen 1)
    end

fun loop (l1, f1) (l2, f2) =
    (case eaquery l1 f1 () of
        ENow (s, f1') => (print s; loop (l2, f2) (l1, f1'))
      | ELater f1' =>
        (case eaquery l2 f2 () of
             ENow (s, f2') => (print s; loop (l2, f2') (l1, f1'))
           | ELater f2' => loop (l2, f2') (l1, f1'))
    )
(*    handle OS.SysErr (s, seo) =>
           (print "s\n";
            (case seo of
                 NONE => ()
               | SOME se => print ((OS.errorMsg se) ^ "\n"));
            raise OS.SysErr (s, seo))
*)

val _ = loop (true, proc_std_in) (false, fibs)
(* val _ = loop fibs fibs *)