open IO
(* val fork = MLton.Parallel.ForkJoin.fork *)

val _ = print "Hi!!!!!!\n"

val start = Time.now ()

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

fun fib n =
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

fun fibloop n =
    if n > 42 then
        let val finish = Time.now ()
            val diff = Time.-(finish, start)
            val diffi = LargeInt.toInt (Time.toMilliseconds diff)
        in
            print ("exectime " ^ (Int.toString diffi) ^ "\n");
            OS.Process.exit OS.Process.success
        end
    else
        (print ("fib(" ^ (Int.toString n) ^ ") = " ^ (Int.toString (fib n)) ^ "\n");
         fibloop (n + 1))

fun inploop () =
    case inputLine () of
        NONE => OS.Process.exit OS.Process.success
      | SOME l =>
        (print ("Hi, " ^ l ^ "\n");
         inploop ())

val _ = MLton.Parallel.ForkJoin.forkLat true ((fn () => fibloop 0), inploop)
(* val _ = loop fibs fibs *)
