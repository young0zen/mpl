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

(* Compute and print Fibonacci of $n$  *)
fun fib n () =
  let fun fib' n () =
      if n <= 1 then n
      else let fun fork (f, g) = if n < 20 then (f (), g ()) else
                              MLton.Parallel.ForkJoin.fork (f, g)
               val (r1, r2) =
                 fork (fib' (n-1), fib' (n-2))
           in r1 + r2
           end
  in print ((Int.toString (fib' n ())) ^ "\n")
  end

(* Read request from user and compute if needed. *)
fun fib_server () =
  let fun loop futures =
        let val request = inputLine ()
        in case request of
             NONE => List.app MLton.Parallel.FutureSuspend.touch futures
           | SOME s =>
             (case Int.fromString s of
                  NONE => loop futures
                | SOME n =>
                  let val _ = print ("Computing fib(" ^ (Int.toString n) ^ ")\n")
                      val f = MLton.Parallel.FutureSuspend.future (fib n)
                  in loop (f::futures) end)
        end
  in loop []
  end

val _ = fib_server ()