------------------------- MODULE VerificationLaunch -------------------------
(***************************************************************************)
(* How the SAS (emoji) ceremony is opened on a device after pairing, and   *)
(* what happens when two devices open it at each other.                    *)
(*                                                                         *)
(* Each active device runs the Lotti UI: one or two                        *)
(* `AutoVerificationLauncher`s (the sync status page and the setup sheet   *)
(* can be mounted at once), an `IncomingVerificationWrapper`, one modal    *)
(* lock, one app-wide set of identities already offered, and a cached view *)
(* of the SDK's unverified device keys that only an invalidation           *)
(* re-reads. A passive device holds keys but never acts: a stale or legacy *)
(* peer in the unverified list.                                            *)
(*                                                                         *)
(* The Matrix SDK's `KeyVerification` is a black box here. A ceremony is   *)
(* `requested` by its initiator, `accepted` by the responder (the incoming *)
(* sheet auto-accepts), `done` once both users confirm the emoji, or       *)
(* `cancelled` by either side. Two devices starting at each other are two  *)
(* ceremonies, as they are two transactions in the SDK; the SDK's own      *)
(* glare rule applies only to a `start` inside one transaction. A device   *)
(* that starts a second ceremony toward the same peer replaces the first   *)
(* in this model; the SDK keeps both, and the peer's sheet stays on the    *)
(* first one.                                                              *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   KeysLand       the SDK downloads a peer's device keys                 *)
(*   Refresh        any `ref.invalidate(matrixUnverifiedControllerProvider)`*)
(*                  — the sheets' finally blocks and refresh loops, the    *)
(*                  roster refresh, the paired view's "Check again"        *)
(*   Launch         AutoVerificationLauncher._maybeLaunch after a rebuild: *)
(*                  pick the first device not yet shown, take the lock,    *)
(*                  record it, open VerificationModal (which starts the    *)
(*                  SDK ceremony)                                          *)
(*   EmptyBuild,    the launcher's empty-list branch and its post-frame    *)
(*   ClearHandled   clear of matrixVerificationHandledProvider             *)
(*   Relaunch       "Show the emoji": matrixVerificationRelaunchProvider,  *)
(*                  every mounted launcher releases the identity it last   *)
(*                  showed and tries to launch                             *)
(*   HandleIncoming IncomingVerificationWrapper on client                  *)
(*                  .onKeyVerificationRequest: open the incoming sheet if  *)
(*                  the lock is free, else drop the request                *)
(*   DeferredOpen   with DeferIncoming, a request held until the lock frees*)
(*   AcceptIncoming IncomingVerificationModal's auto-accept                *)
(*   AcceptSas      the user confirms the emoji on either sheet            *)
(*   Cancel         the Cancel button on either sheet                      *)
(*   Dismiss        a backdrop tap, or Done on a finished ceremony         *)
(*                                                                         *)
(* Switches. RecordOnlyShown, SharedHandled and ReleaseOne are three fixes *)
(* that shipped before this model; each FALSE is the bug it fixed.         *)
(* GlareHandoff and PreferLastShown are the two fixes this model found;    *)
(* FALSE is the code before them. DeferIncoming and CancelOnDismiss are    *)
(* alternatives TLC rejected, kept so the README's table can be re-run.    *)
(* Cooperative users confirm, and never cancel or abandon a live ceremony: *)
(* the automatic flow has to finish on its own.                            *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS
    Devices,          \* device identities, ordered as the SDK orders them
    Active,           \* the devices that run the UI; the rest are passive
    Launchers,        \* the launchers mounted on every active device
    MaxRelaunch,      \* bound on "Show the emoji" taps
    Cooperative,      \* users confirm, and never cancel or abandon a live ceremony
    DeferIncoming,    \* an incoming request waits for the lock instead of being dropped
    GlareHandoff,     \* a launcher answers the peer's waiting request rather than
                      \* starting its own, and a device whose request is still
                      \* unanswered yields to an incoming one (see Yield)
    CancelOnDismiss,  \* abandoning a sheet cancels its SDK ceremony
    PreferLastShown,  \* a relaunch reopens the identity last shown app-wide, not
                      \* the first unhandled device in list order
    RecordOnlyShown,  \* record an identity only when its sheet was shown
    SharedHandled,    \* the handled set is app-wide, not per launcher
    ReleaseOne        \* a relaunch releases the identity last shown, not the whole set

ASSUME Active \subseteq Devices /\ Launchers # {} /\ Devices \subseteq Nat

None == 0
Peers(d) == Devices \ {d}
NoSheet == [kind |-> "none", peer |-> None, via |-> None]
Phases == {"none", "requested", "accepted", "done", "cancelled"}

VARIABLES
    present,       \* present[d][e]: d holds e's device keys
    verified,      \* verified[d][e]: d trusts e; symmetric once a ceremony is done
    view,          \* view[d]: the unverified-devices provider's last value
    lock,          \* lock[d]: "free", "launch" or "incoming"
    handled,       \* handled[d][l]: identities launcher l on d recorded as shown
    lastOffered,   \* lastOffered[d][l]: the identity launcher l last showed
    clearPending,  \* clearPending[d][l]: a post-frame clear is scheduled
    sheet,         \* sheet[d]: the open ceremony sheet — kind, peer, launcher
    cer,           \* cer[i][r]: the ceremony i started toward r
    sas,           \* sas[i][r]: who has confirmed its emoji
    inbox,         \* inbox[r]: requests that reached r's UI, not yet handled
    deferred,      \* deferred[r]: requests waiting for r's lock
    relaunches,
    offered,       \* ghost: offered[d][e], a launcher showed e's ceremony on d
    seen,          \* ghost: seen[d][e], any sheet for e was shown on d
    relaunchSince, \* ghost: relaunchSince[d][e], a relaunch since e was last offered
    lastSeen,      \* ghost: lastSeen[d], the peer of the launcher sheet last opened on d
    reoffer,       \* ghost: a device was offered again without being asked
    relaunchMiss   \* ghost: a relaunch skipped the device the user was looking at

vars == <<present, verified, view, lock, handled, lastOffered, clearPending,
          sheet, cer, sas, inbox, deferred, relaunches, offered, seen,
          relaunchSince, lastSeen, reoffer, relaunchMiss>>

PairMap(v) == [d \in Devices |-> [e \in Devices |-> v]]
LauncherMap(v) == [d \in Devices |-> [l \in Launchers |-> v]]

Init ==
    /\ present = PairMap(FALSE)
    /\ verified = PairMap(FALSE)
    /\ view = [d \in Devices |-> {}]
    /\ lock = [d \in Devices |-> "free"]
    /\ handled = LauncherMap({})
    /\ lastOffered = LauncherMap(None)
    /\ clearPending = LauncherMap(FALSE)
    /\ sheet = [d \in Devices |-> NoSheet]
    /\ cer = PairMap("none")
    /\ sas = PairMap({})
    /\ inbox = [d \in Devices |-> {}]
    /\ deferred = [d \in Devices |-> {}]
    /\ relaunches = 0
    /\ offered = PairMap(FALSE)
    /\ seen = PairMap(FALSE)
    /\ relaunchSince = PairMap(FALSE)
    /\ lastSeen = [d \in Devices |-> None]
    /\ reoffer = FALSE
    /\ relaunchMiss = FALSE

----------------------------------------------------------------------------
(* Derived state. *)

Unverified(d) == {e \in Peers(d) : present[d][e] /\ ~verified[d][e]}

\* The identities launcher l on d treats as already shown, in a handled map.
HandledIn(h, d, l) ==
    IF SharedHandled THEN UNION {h[d][m] : m \in Launchers} ELSE h[d][l]

Handled(d, l) == HandledIn(handled, d, l)

MarkIn(h, d, l, t) ==
    IF SharedHandled
    THEN [h EXCEPT ![d] = [m \in Launchers |-> @[m] \cup {t}]]
    ELSE [h EXCEPT ![d][l] = @ \cup {t}]

\* The SDK phase the sheet on d renders, from the ceremony it belongs to.
Phase(d) ==
    CASE sheet[d].kind = "out" -> cer[d][sheet[d].peer]
      [] sheet[d].kind = "in" -> cer[sheet[d].peer][d]
      [] OTHER -> "none"

Terminal(p) == p \in {"done", "cancelled"}

\* Post-frame callbacks of one frame run before the next frame builds.
NoClearPending(d) == \A l \in Launchers : ~clearPending[d][l]

\* The peer's own request toward d is still pending in d's SDK — whether or
\* not the wrapper could show it: MatrixService keeps the latest incoming
\* runner either way.
Waiting(d, t) == cer[t][d] = "requested"

----------------------------------------------------------------------------
(* Keys and the cached view. *)

KeysLand(d, e) ==
    /\ d \in Active
    /\ e \in Peers(d)
    /\ ~present[d][e]
    /\ present' = [present EXCEPT ![d][e] = TRUE]
    /\ UNCHANGED <<verified, view, lock, handled, lastOffered, clearPending,
                   sheet, cer, sas, inbox, deferred, relaunches, offered, seen,
                   relaunchSince, lastSeen, reoffer, relaunchMiss>>

\* An invalidation of matrixUnverifiedControllerProvider re-reads the SDK.
Refresh(d) ==
    /\ d \in Active
    /\ view[d] # Unverified(d)
    /\ view' = [view EXCEPT ![d] = Unverified(d)]
    /\ UNCHANGED <<present, verified, lock, handled, lastOffered, clearPending,
                   sheet, cer, sas, inbox, deferred, relaunches, offered, seen,
                   relaunchSince, lastSeen, reoffer, relaunchMiss>>

----------------------------------------------------------------------------
(* Opening and closing sheets. *)

\* IncomingVerificationModal opens on r for the ceremony i started.
OpenIn(r, i) ==
    /\ lock' = [lock EXCEPT ![r] = "incoming"]
    /\ sheet' = [sheet EXCEPT ![r] = [kind |-> "in", peer |-> i, via |-> None]]
    /\ seen' = [seen EXCEPT ![r][i] = TRUE]

\* Launcher l on d shows t's ceremony. Under GlareHandoff a request t already
\* sent is answered in place; otherwise VerificationModal starts a ceremony
\* of its own, whose request reaches t's UI layer if t runs one.
Show(d, l, t) ==
    /\ lock' = [lock EXCEPT ![d] = "launch"]
    /\ lastOffered' = [lastOffered EXCEPT ![d][l] = t]
    /\ offered' = [offered EXCEPT ![d][t] = TRUE]
    /\ seen' = [seen EXCEPT ![d][t] = TRUE]
    /\ lastSeen' = [lastSeen EXCEPT ![d] = t]
    /\ IF GlareHandoff /\ Waiting(d, t)
       THEN /\ sheet' = [sheet EXCEPT ![d] = [kind |-> "in", peer |-> t, via |-> l]]
            /\ inbox' = [inbox EXCEPT ![d] = @ \ {t}]
            /\ deferred' = [deferred EXCEPT ![d] = @ \ {t}]
            /\ UNCHANGED <<cer, sas>>
       ELSE /\ sheet' = [sheet EXCEPT ![d] = [kind |-> "out", peer |-> t, via |-> l]]
            /\ cer' = [cer EXCEPT ![d][t] = "requested"]
            /\ sas' = [sas EXCEPT ![d][t] = {}]
            /\ inbox' = IF t \in Active THEN [inbox EXCEPT ![t] = @ \cup {d}] ELSE inbox
            /\ UNCHANGED deferred

\* A sheet closes: the lock frees and the finally block re-reads the view.
Close(d) ==
    /\ lock' = [lock EXCEPT ![d] = "free"]
    /\ sheet' = [sheet EXCEPT ![d] = NoSheet]
    /\ view' = [view EXCEPT ![d] = Unverified(d)]

----------------------------------------------------------------------------
(* The launcher. *)

\* A rebuild's post-frame callback: the first device not yet shown, if the
\* lock is free. With RecordOnlyShown off, a device is recorded even when
\* another sheet holds the lock — the "burn-through" bug.
Launch(d, l) ==
    /\ d \in Active
    /\ sheet[d].via # l
    /\ NoClearPending(d)
    /\ \E t \in view[d] \ Handled(d, l) :
         IF lock[d] = "free"
         THEN /\ Show(d, l, t)
              /\ handled' = MarkIn(handled, d, l, t)
              /\ reoffer' = (reoffer \/ (offered[d][t] /\ ~relaunchSince[d][t]))
              /\ relaunchSince' = [relaunchSince EXCEPT ![d][t] = FALSE]
              /\ UNCHANGED <<present, verified, view, clearPending, relaunches,
                             relaunchMiss>>
         ELSE /\ ~RecordOnlyShown
              /\ handled' = MarkIn(handled, d, l, t)
              /\ UNCHANGED <<present, verified, view, lock, lastOffered,
                             clearPending, sheet, cer, sas, inbox, deferred,
                             relaunches, offered, seen, relaunchSince,
                             lastSeen, reoffer, relaunchMiss>>

\* The launcher rebuilds on an empty view: it forgets what it last offered
\* and schedules the clear of the handled set for after the frame.
EmptyBuild(d, l) ==
    /\ d \in Active
    /\ view[d] = {}
    /\ ~clearPending[d][l]
    /\ lastOffered[d][l] # None \/ Handled(d, l) # {}
    /\ lastOffered' = [lastOffered EXCEPT ![d][l] = None]
    /\ clearPending' = [clearPending EXCEPT ![d][l] = TRUE]
    /\ UNCHANGED <<present, verified, view, lock, handled, sheet, cer, sas,
                   inbox, deferred, relaunches, offered, seen, relaunchSince,
                   lastSeen, reoffer, relaunchMiss>>

ClearHandled(d, l) ==
    /\ clearPending[d][l]
    /\ clearPending' = [clearPending EXCEPT ![d][l] = FALSE]
    /\ handled' = IF SharedHandled
                  THEN [handled EXCEPT ![d] = [m \in Launchers |-> {}]]
                  ELSE [handled EXCEPT ![d][l] = {}]
    /\ UNCHANGED <<present, verified, view, lock, lastOffered, sheet, cer, sas,
                   inbox, deferred, relaunches, offered, seen, relaunchSince,
                   lastSeen, reoffer, relaunchMiss>>

\* The handled set after every mounted launcher's relaunch listener released.
\* With PreferLastShown the identity last shown on the device is released,
\* whichever launcher showed it; otherwise each launcher releases its own.
Released(d) ==
    IF PreferLastShown
    THEN [handled EXCEPT ![d] = [m \in Launchers |-> @[m] \ {lastSeen[d]}]]
    ELSE IF ReleaseOne
    THEN IF SharedHandled
         THEN [handled EXCEPT ![d] = [m \in Launchers |->
                 @[m] \ {lastOffered[d][k] : k \in Launchers}]]
         ELSE [handled EXCEPT ![d] = [m \in Launchers |-> @[m] \ {lastOffered[d][m]}]]
    ELSE [handled EXCEPT ![d] = [m \in Launchers |-> {}]]

\* What launcher l on d may open from a relaunch, over the released set h.
Targets(h, d, l) ==
    IF PreferLastShown /\ lastSeen[d] \in view[d]
    THEN {lastSeen[d]}
    ELSE view[d] \ HandledIn(h, d, l)

\* "Show the emoji": the button is enabled only while the view is non-empty,
\* and only reachable while no sheet is open. Every listener releases, then
\* the listeners try to launch in mount order; nondeterministic here.
Relaunch(d) ==
    /\ d \in Active
    /\ relaunches < MaxRelaunch
    /\ view[d] # {}
    /\ sheet[d].kind = "none"
    /\ NoClearPending(d)
    /\ relaunches' = relaunches + 1
    /\ LET h == Released(d)
           candidates == {l \in Launchers : Targets(h, d, l) # {}}
           wanted == lastSeen[d] \in view[d]
       IN IF candidates = {}
          THEN /\ handled' = h
               /\ relaunchMiss' = (relaunchMiss \/ wanted)
               /\ relaunchSince' = [relaunchSince EXCEPT ![d] = [e \in Devices |-> TRUE]]
               /\ UNCHANGED <<present, verified, view, lock, lastOffered,
                              clearPending, sheet, cer, sas, inbox, deferred,
                              offered, seen, lastSeen, reoffer>>
          ELSE \E l \in candidates : \E t \in Targets(h, d, l) :
               /\ Show(d, l, t)
               /\ handled' = MarkIn(h, d, l, t)
               /\ relaunchMiss' = (relaunchMiss \/ (wanted /\ t # lastSeen[d]))
               /\ relaunchSince' = [relaunchSince EXCEPT ![d] = [e \in Devices |-> e # t]]
               /\ UNCHANGED <<present, verified, view, clearPending, reoffer>>

----------------------------------------------------------------------------
(* Incoming requests. *)

\* r's own sheet still waits on a request nobody has answered.
Unanswered(r) ==
    sheet[r].kind = "out" /\ cer[r][sheet[r].peer] = "requested"

\* Whether r gives up its unanswered request to answer i's instead: only to
\* a smaller identity. The order is what makes it terminate — the smallest
\* device in any tangle never yields, so its ceremony is the one that
\* finishes, and yielding to any third device instead let three devices
\* withdraw ceremonies from under each other forever. When two devices start
\* at each other it is the SDK's own rule for a `start` glare, applied one
\* step earlier.
Yield(r, i) == Unanswered(r) /\ i < r

\* The wrapper receives i's request: the sheet opens if the lock is free;
\* under GlareHandoff a yielding device cancels its own ceremony and shows
\* i's inside the sheet it already holds; under DeferIncoming the request
\* waits for the lock; otherwise it is dropped.
HandleIncoming(r, i) ==
    /\ r \in Active
    /\ i \in inbox[r]
    /\ inbox' = [inbox EXCEPT ![r] = @ \ {i}]
    /\ IF cer[i][r] # "requested"
       THEN UNCHANGED <<lock, sheet, seen, cer, deferred, handled, offered>>
       ELSE IF lock[r] = "free"
       THEN /\ OpenIn(r, i)
            /\ UNCHANGED <<cer, deferred, handled, offered>>
       ELSE IF GlareHandoff /\ Yield(r, i)
       THEN /\ cer' = [cer EXCEPT ![r][sheet[r].peer] = "cancelled"]
            /\ sheet' = [sheet EXCEPT ![r] =
                           [kind |-> "in", peer |-> i, via |-> @.via]]
            /\ seen' = [seen EXCEPT ![r][i] = TRUE]
            \* The peer whose ceremony was just withdrawn was never really
            \* offered one: it must stay eligible for the launcher.
            /\ handled' = [handled EXCEPT ![r] =
                             [m \in Launchers |-> @[m] \ {sheet[r].peer}]]
            /\ offered' = [offered EXCEPT ![r][sheet[r].peer] = FALSE]
            /\ UNCHANGED <<lock, deferred>>
       ELSE IF DeferIncoming
       THEN /\ deferred' = [deferred EXCEPT ![r] = @ \cup {i}]
            /\ UNCHANGED <<lock, sheet, seen, cer, handled, offered>>
       ELSE UNCHANGED <<lock, sheet, seen, cer, deferred, handled, offered>>
    /\ UNCHANGED <<present, verified, view, lastOffered, clearPending,
                   sas, relaunches, relaunchSince, lastSeen, reoffer,
                   relaunchMiss>>

DeferredOpen(r) ==
    /\ lock[r] = "free"
    /\ \E i \in deferred[r] :
         /\ deferred' = [deferred EXCEPT ![r] = @ \ {i}]
         /\ IF cer[i][r] = "requested"
            THEN OpenIn(r, i)
            ELSE UNCHANGED <<lock, sheet, seen>>
    /\ UNCHANGED <<present, verified, view, handled, lastOffered, clearPending,
                   cer, sas, inbox, relaunches, offered, relaunchSince,
                   lastSeen, reoffer, relaunchMiss>>

----------------------------------------------------------------------------
(* The ceremony. *)

AcceptIncoming(r) ==
    /\ sheet[r].kind = "in"
    /\ LET i == sheet[r].peer IN
       /\ cer[i][r] = "requested"
       /\ cer' = [cer EXCEPT ![i][r] = "accepted"]
    /\ UNCHANGED <<present, verified, view, lock, handled, lastOffered,
                   clearPending, sheet, sas, inbox, deferred, relaunches,
                   offered, seen, relaunchSince, lastSeen, reoffer,
                   relaunchMiss>>

\* The user compares the emoji and confirms. The second confirmation
\* finishes the ceremony and both devices trust each other.
AcceptSas(d) ==
    /\ sheet[d].kind # "none"
    /\ Phase(d) = "accepted"
    /\ LET i == IF sheet[d].kind = "out" THEN d ELSE sheet[d].peer
           r == IF sheet[d].kind = "out" THEN sheet[d].peer ELSE d
           both == sas[i][r] \cup {d}
       IN /\ d \notin sas[i][r]
          /\ sas' = [sas EXCEPT ![i][r] = both]
          /\ IF both = {i, r}
             THEN /\ cer' = [cer EXCEPT ![i][r] = "done"]
                  /\ verified' = [verified EXCEPT ![i][r] = TRUE, ![r][i] = TRUE]
             ELSE UNCHANGED <<cer, verified>>
    /\ UNCHANGED <<present, view, lock, handled, lastOffered, clearPending,
                   sheet, inbox, deferred, relaunches, offered, seen,
                   relaunchSince, lastSeen, reoffer, relaunchMiss>>

\* The Cancel button: the SDK ceremony is cancelled and the sheet pops.
Cancel(d) ==
    /\ ~Cooperative
    /\ sheet[d].kind # "none"
    /\ Phase(d) \in {"requested", "accepted"}
    /\ LET i == IF sheet[d].kind = "out" THEN d ELSE sheet[d].peer
           r == IF sheet[d].kind = "out" THEN sheet[d].peer ELSE d
       IN cer' = [cer EXCEPT ![i][r] = "cancelled"]
    /\ Close(d)
    /\ UNCHANGED <<present, verified, handled, lastOffered, clearPending, sas,
                   inbox, deferred, relaunches, offered, seen, relaunchSince,
                   lastSeen, reoffer, relaunchMiss>>

\* Done on a finished ceremony, or a backdrop tap on a live one. The live
\* SDK ceremony survives an abandoned sheet unless CancelOnDismiss.
Dismiss(d) ==
    /\ sheet[d].kind # "none"
    /\ Terminal(Phase(d)) \/ ~Cooperative
    /\ LET i == IF sheet[d].kind = "out" THEN d ELSE sheet[d].peer
           r == IF sheet[d].kind = "out" THEN sheet[d].peer ELSE d
       IN cer' = IF CancelOnDismiss /\ ~Terminal(Phase(d))
                 THEN [cer EXCEPT ![i][r] = "cancelled"] ELSE cer
    /\ Close(d)
    /\ UNCHANGED <<present, verified, handled, lastOffered, clearPending, sas,
                   inbox, deferred, relaunches, offered, seen, relaunchSince,
                   lastSeen, reoffer, relaunchMiss>>

\* A sheet that waits on a request nobody will answer is eventually given up
\* on — the one dismissal even a patient user performs.
DismissStuck(d) == Dismiss(d) /\ Phase(d) = "requested"

----------------------------------------------------------------------------

Next ==
    \/ \E d \in Devices :
          \/ \E e \in Devices : KeysLand(d, e)
          \/ Refresh(d) \/ Relaunch(d) \/ DeferredOpen(d)
          \/ AcceptIncoming(d) \/ AcceptSas(d) \/ Cancel(d) \/ Dismiss(d)
          \/ \E l \in Launchers : Launch(d, l) \/ EmptyBuild(d, l) \/ ClearHandled(d, l)
          \/ \E i \in Devices : HandleIncoming(d, i)

Fairness ==
    \A d \in Devices :
        /\ WF_vars(Refresh(d))
        /\ WF_vars(DeferredOpen(d))
        /\ WF_vars(AcceptIncoming(d))
        /\ WF_vars(AcceptSas(d))
        /\ WF_vars(Dismiss(d) /\ Terminal(Phase(d)))
        /\ ~Cooperative => WF_vars(DismissStuck(d))
        /\ \A l \in Launchers :
              WF_vars(Launch(d, l)) /\ WF_vars(EmptyBuild(d, l)) /\ WF_vars(ClearHandled(d, l))
        /\ \A i \in Devices : WF_vars(HandleIncoming(d, i))

Spec == Init /\ [][Next]_vars /\ Fairness

----------------------------------------------------------------------------
(* Properties. *)

TypeOK ==
    /\ \A d \in Devices :
          /\ lock[d] \in {"free", "launch", "incoming"}
          /\ sheet[d].kind \in {"none", "out", "in"}
          /\ view[d] \subseteq Peers(d)
          /\ \A e \in Devices : cer[d][e] \in Phases /\ sas[d][e] \subseteq {d, e}
    /\ relaunches \in 0..MaxRelaunch

\* The lock is held exactly while a sheet is open.
LockMatchesSheet ==
    \A d \in Devices : (lock[d] = "free") <=> (sheet[d].kind = "none")

\* Trust is mutual: a finished ceremony verifies both devices in one step.
\* (A later ceremony between verified devices — a launcher acting on a stale
\* view — re-verifies them, so the finished ceremony need not be the last.)
VerifiedByCeremony ==
    \A d, e \in Devices : verified[d][e] => verified[e][d]

\* Only a device whose ceremony was actually shown is recorded as handled.
HandledWasShown ==
    \A d \in Devices, l \in Launchers : \A e \in Handled(d, l) : offered[d][e]

\* A dismissed ceremony is not offered again unless the user asks.
NoReoffer == ~reoffer

\* "Show the emoji" reopens the device the user was looking at.
RelaunchHonoured == ~relaunchMiss

\* Every unverified peer whose keys arrived is eventually offered a ceremony,
\* by this device's launcher or by the peer's request.
EventuallyOffered ==
    \A d \in Active, e \in Devices :
        (present[d][e] /\ ~verified[d][e]) ~> (seen[d][e] \/ verified[d][e])

\* Two active devices that hold each other's keys end up verified without
\* anyone asking for the ceremony again.
AutoVerifies ==
    \A d, e \in Active : d # e =>
        (present[d][e] /\ present[e][d]) ~> verified[d][e]
=============================================================================
