(* Author: Sam Westrick (swestric@cs.cmu.edu) *)

(* Scheduler implements a single structure.
 *   ForkJoin : FORK_JOIN
 * It is pulled out of Scheduler at the bottom of this file. *)
structure Scheduler =
struct

  structure Thread = MLton.Thread.Basic
  fun threadSwitch t =
    ( Thread.atomicBegin ()
    ; Thread.switchTo t
    )

  structure HM = MLton.HM
  structure HH = HM.HierarchicalHeap

  val P = MLton.Parallel.numberOfProcessors
  val myWorkerId = MLton.Parallel.processorNumber

  (* ----------------------------------------------------------------------- *
   * ------------------------------ DEBUGGING ------------------------------ *
   * ----------------------------------------------------------------------- *)

  fun die strfn =
    ( print (Int.toString (myWorkerId ()) ^ ": " ^ strfn ())
    ; OS.Process.exit OS.Process.failure
    )

  val doDebugMsg = false

  val printLock : Word32.word ref = ref 0w0
  val _ = MLton.Parallel.Deprecated.lockInit printLock
  fun dbgmsg m =
    if not doDebugMsg then () else
    let
      val p = myWorkerId ()
      val _ = MLton.Parallel.Deprecated.takeLock printLock
      val msg = String.concat ["[", Int.toString p, "] ", m(), "\n"]
    in
      ( TextIO.output (TextIO.stdErr, msg)
      ; TextIO.flushOut TextIO.stdErr
      ; MLton.Parallel.Deprecated.releaseLock printLock
      )
    end

  (* ----------------------------------------------------------------------- *
   * ----------------------------------------------------------------------- *
   * ----------------------------------------------------------------------- *)

  val vcas = MLton.Parallel.compareAndSwap
  fun cas (r, old, new) = vcas r (old, new) = old

  fun faa (r, d) = MLton.Parallel.fetchAndAdd r d

  (* TODO: Implement a faster queue? Is this necessary? *)
  (*structure Queue = SimpleQueue*)
  (* structure Queue = DoublyLinkedList *)
  (* structure Queue = MkRingBuffer (val initialCapacity = 1024) *)
  structure Queue = ArrayQueue

  fun newIncounter () = ref 2

  fun decrementHitsZero (x : int ref) : bool =
    faa (x, ~1) = 1

  fun useHH (hh : unit HH.t) : unit =
    ( HM.enterGlobalHeap ()
    ; HH.set hh
    ; HH.setUseHierarchicalHeap true
    ; HM.exitGlobalHeap ()
    )

  fun stopUseHH (() : unit) : unit =
    ( HM.enterGlobalHeap ()
    ; HH.setUseHierarchicalHeap false (* also unsets the hh *)
    ; HM.exitGlobalHeap ()
    )

  fun arraySub (a, i) = Array.sub (a, i)
  fun arrayUpdate (a, i, x) = Array.update (a, i, x)
  fun vectorSub (v, i) = Vector.sub (v, i)

  (* A request is either NO_REQUEST, REQUEST_BLOCKED, or a processor id.
   * Workers request work by writing their own id into another worker's
   * request cell. If a worker is idle, it blocks requests from other workers
   * by changing its own request cell to REQUEST_BLOCKED. *)
  val NO_REQUEST = ~1
  val REQUEST_BLOCKED = ~2
  val requestCells = Vector.tabulate (P, fn _ => ref NO_REQUEST)
  fun requestCell p = vectorSub (requestCells, p)

  (* Statuses are updated locally to indicate whether or not work is available
   * to be stolen. This allows idle workers to only request work from victims
   * who are unlikely to reject.
   * TODO: does padding statuses actually improve performance? *)
  val statuses = Array.array (P*16, false)
  fun getStatus p = arraySub (statuses, p*16)
  fun setStatus (p, s) = arrayUpdate (statuses, p*16, s)

  val mailboxes : ((unit -> unit) * unit HH.t) option Mailboxes.t =
    Mailboxes.new NONE

  (* val push : task -> unit
   * push onto the current work queue *)
  val pushFuncs = Array.array (P, fn _ => die (fn _ => "Error: dummy push"))
  fun push x = arraySub (pushFuncs, myWorkerId ()) x

  (* val popDiscard : unit -> bool
   * Attempts to pop a task off the task queue. If it fails (because the queue
   * is empty) then the desired task must have been served to another worker. *)
  val popDiscardFuncs = Array.array (P, fn _ => (die (fn _ => "Error: dummy popDiscard"); false))
  fun popDiscard () = arraySub (popDiscardFuncs, myWorkerId ()) ()

  (* val communicateFuncs = Array.array (P, fn _ => die (fn _ => "Error: dummy communicate"))
  fun communicate () = arraySub "communicateFuncs" (communicateFuncs, myWorkerId ()) () *)

  val returnToScheds = Array.array (P, fn _ => die (fn _ => "Error: dummy returnToSched"))
  fun returnToSched x = arraySub (returnToScheds, myWorkerId ()) x

  (* ----------------------------------------------------------------------- *
   * ------------------------------ FORK-JOIN ------------------------------ *
   * ------------------------------------------------------------------------*)

  structure ForkJoin :> FORK_JOIN =
  struct

    exception ForkJoin

    datatype 'a result =
      Finished of 'a
    | Raised of exn

    (* Must be called from a "user" thread, which has an associated HH *)
    (* NOTE: ALL HH OBJECTS MUST RESIDE IN THE GLOBAL HEAP *)
    fun fork (f : unit -> 'a, g : unit -> 'b) =
      let
        val hh = HH.get ()
        val level = HH.getLevel hh

        val _ = dbgmsg (fn _ => "fork at level " ^ Int.toString level)

        (* This only works if the chosen SOME/NONE representation is a single objptr *)
        val ghhr = ref (NONE : 'b result ref HH.t option)
        val incounter = newIncounter ()
        val parentThread = Thread.current ()

        fun g' () =
          let
            val result = Finished (g ()) handle e => Raised e
            (* We only use `ref` to guarantee the value gets boxed! *)
            val ghh = HH.setReturnValue (HH.get (), ref result)
            val _ = ghhr := SOME ghh
            (* not necessary to set dead in private-deques, but still have to
             * in order to play nice with the current runtime implementation *)
            val _ = HH.setDead ghh
          in
            returnToSched (incounter, parentThread)
          end

        val _ = dbgmsg (fn _ => "pushing")

        val _ = push (g', hh, level)
        val _ = HH.setLevel (hh, level + 1)

        val a = f ()
        val _ = dbgmsg (fn _ => "trying pop")
        val b =
          if popDiscard () then
            g ()
          else
            ( dbgmsg (fn _ => "suspending")
            ; returnToSched (incounter, parentThread)
            ; case !ghhr of
                NONE => raise ForkJoin
              | SOME ghh =>
                  case !(HH.mergeIntoParentAndGetReturnValue ghh) of
                    Finished b => b
                  | Raised e => raise e
            )

        (* moves chunks from level+1 to level *)
        val _ = HH.promoteChunks hh
        val _ = HH.setLevel (hh, level)

        val _ = dbgmsg (fn _ => "finish fork at level " ^ Int.toString level)
      in
        (a, b)
      end

  end

  (* ----------------------------------------------------------------------- *
   * ------------------------- WORKER-LOCAL SETUP -------------------------- *
   * ----------------------------------------------------------------------- *)


  (* We maintain a distinction between
   *   - "scheduler" threads, which never are migrated between processors and
   *   are used to acquire new work when the processor becomes idle, and
   *   - "user" threads, which run user code and are migrated between processors
   *)
  fun sched rootTask () =
    let
      val myId = myWorkerId ()
      val myQueue = Queue.new myId
      val myRand = SimpleRandom.rand myId
      val myRequestCell = requestCell myId
      val mySchedThread = Thread.current ()
      val myRetArg = ref NONE

      (* this widget makes it possible to create new "user" threads by copying
       * the prototype thread and writing the piece of work which should be
       * executed into the `myTodo` cell *)
      val myTodo : (unit -> unit) option ref = ref NONE
      val _ = Thread.copyCurrent ()
      val prototype : Thread.p =
        case !myTodo of
          NONE => Thread.savedPre ()
        | SOME f =>
            ( myTodo := NONE
            ; f () handle e => MLton.Exn.topLevelHandler e
            ; die (fn _ => "Scheduler: thread didn't exit properly")
            )

      (* the lock is not necessary for private deques, but need to do this to
       * play nice with runtime. *)
      val dummyLock : Word32.word ref = ref 0w0
      val _ = MLton.HM.registerQueueLock (Word32.fromInt myId, dummyLock)
      val _ = MLton.Parallel.Deprecated.lockInit dummyLock

      fun communicate () =
        ( let
            val friend = !myRequestCell
          in
            if friend = NO_REQUEST then ()
            else if friend = REQUEST_BLOCKED then die (fn _ => "Error: serve while blocked")
            else ( myRequestCell := NO_REQUEST
                 ; case Queue.popBack myQueue of
                     NONE => Mailboxes.sendMail mailboxes (friend, NONE)
                   | SOME (task, phh, level) =>
                       let
                         val _ = dbgmsg (fn _ => "append child at level " ^ Int.toString level)
                         val _ = HM.enterGlobalHeap ()
                         val chh = HH.new ()
                         val _ = HH.appendChild (phh, chh, level)
                         val _ = HM.exitGlobalHeap ()
                       in
                         Mailboxes.sendMail mailboxes (friend, SOME (task, chh))
                       end
                 )
          end
        ; setStatus (myId, not (Queue.empty myQueue))
        )

      fun push x =
        Queue.pushFront (x, myQueue)
        before communicate ()

      fun popDiscard () =
        (case Queue.popFront myQueue of
          NONE => false
        | SOME _ => true)
        before communicate ()

      (* ------------------------------------------------------------------- *)

      fun verifyStatus () =
        if getStatus myId = false then ()
        else die (fn _ => "Error: status not set correctly\n")

      fun randomOtherId () =
        let val other = SimpleRandom.boundedInt (0, P-1) myRand
        in if other < myId then other else other+1
        end

      fun blockRequests () =
        let
          val friend = !myRequestCell
        in
          if friend = NO_REQUEST then
            if cas (myRequestCell, NO_REQUEST, REQUEST_BLOCKED) then ()
            else blockRequests () (* recurs at most once *)
          else if friend = REQUEST_BLOCKED then die (fn _ => "Error: block while blocked")
          else
            ( myRequestCell := REQUEST_BLOCKED
            ; Mailboxes.sendMail mailboxes (friend, NONE)
            )
        end

      fun unblockRequests () = myRequestCell := NO_REQUEST

      fun request () =
        let
          val victimId = randomOtherId ()
          val hasWork = getStatus victimId
        in
          if not (hasWork andalso cas (requestCell victimId, NO_REQUEST, myId))
          then (verifyStatus (); request ())
          else case Mailboxes.getMail mailboxes myId of
                 NONE => (verifyStatus (); request ())
               | SOME m => m
        end

      (* ------------------------------------------------------------------- *)

      fun acquireWork () : unit =
        let
          val _ = setStatus (myId, false)
          val _ = blockRequests ()
          val _ = dbgmsg (fn _ => "finding work")
          val (task, hh) = request () (* loop until work is found... *)
          val _ = dbgmsg (fn _ => "got work")
          val _ = unblockRequests ()

          (* val _ = useHH hh *)
          val _ = myTodo := SOME (fn _ => (useHH hh; task ()))
          val taskThread = Thread.copy prototype
          (* val _ = stopUseHH () *)
          val _ = threadSwitch taskThread
        in
          returnFromExecute ()
        end

      and returnFromExecute () =
        case !myRetArg of
          NONE => die (fn _ => "Error: no ret arg upon return to scheduler")
        | SOME (incounter, cont) =>
            ( myRetArg := NONE
            ; if decrementHitsZero incounter
              then (communicate (); threadSwitch cont; returnFromExecute ())
              else acquireWork ()
            )

      fun returnToSched (c, k) =
        ( myRetArg := SOME (c, k)
        ; threadSwitch mySchedThread
        )

      (* ------------------------------------------------------------------- *)

      val _ = arrayUpdate (pushFuncs, myId, push)
      val _ = arrayUpdate (popDiscardFuncs, myId, popDiscard)
      val _ = arrayUpdate (returnToScheds, myId, returnToSched)

      val _ = dbgmsg (fn _ => "sched " ^ Int.toString myId ^ " finished init")

    in
      case rootTask of
        NONE => acquireWork ()
      | SOME t => (threadSwitch t; returnFromExecute ())
    end

  (* ----------------------------------------------------------------------- *
   * --------------------------- INITIALIZATION ---------------------------- *
   * ----------------------------------------------------------------------- *)

  val _ = MLton.Parallel.registerProcessorFunction (sched NONE)
  val _ = MLton.Parallel.initializeProcessors ()

  val executeMain = ref false
  val rootHH = HH.new ()
  val _ = dbgmsg (fn _ => "copying current")
  val _ = Thread.copyCurrent ()

  (* this manages to hijack the "original" program thread as the scheduler
   * thread, while the copied thread is used to execute the actual program. *)
  val _ =
    if !executeMain then ()
    else let
           val _ = dbgmsg (fn _ => "copy savedPre into hh")
           (* val _ = useHH rootHH *)
           val t = SOME (Thread.copy (Thread.savedPre ()))
           (* val _ = stopUseHH () *)
         in
           ( executeMain := true
           ; sched t ()
           ; die (fn _ => "Error: main sched returned")
           )
         end

  val _ = dbgmsg (fn _ => "executing main")
  val _ = useHH rootHH

end

structure ForkJoin :> FORK_JOIN = Scheduler.ForkJoin
