---------------------------- MODULE DevicePairing ----------------------------
(***************************************************************************)
(* The inviting side of pairing: the Add Device sheet shows a handover     *)
(* code, watches the account's device roster for a session that was not   *)
(* there when it opened, and follows one exact device through the SAS     *)
(* ceremony before it unlocks the two transfers (settings, history) toward *)
(* that device. The joining side is `VerificationLaunch`.                  *)
(*                                                                         *)
(* The sheet has three ordered facts to establish — which sessions existed *)
(* before the code was shown, that a new one joined, and which one a       *)
(* finished ceremony named — from three asynchronous sources: a roster     *)
(* fetch it does not time, a poll, and a verification stream it may have   *)
(* joined late. Getting the order wrong either names an old device as the  *)
(* new one or never names the new one at all.                              *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   Open          AddDeviceView.initState → _generate: the sheet opens,   *)
(*                 subscribes to both runner streams and records the       *)
(*                 runners MatrixService already retains                   *)
(*   ShowCode      _generate completes: the handover code is on screen     *)
(*   Fetch         syncDevicesControllerProvider resolves or refreshes     *)
(*   Snapshot      _observeRoster's first run: `_knownDeviceIds`           *)
(*   ObserveRoster _observeRoster afterwards: a row outside the snapshot   *)
(*                 means a device joined                                   *)
(*   Start, Finish a ceremony between this device and a roster device,     *)
(*                 before or after the sheet opened                        *)
(*   ObserveVerif. _observeVerification on a runner the stream emits       *)
(*   Join          a device consumes the code and appears on the roster    *)
(*   Close         the sheet is dismissed                                  *)
(*                                                                         *)
(* Switches, each a fix: SnapshotBeforeCode makes _generate take the       *)
(* roster snapshot before it shows the code (today the snapshot is taken   *)
(* by the first build after the code is up, from whatever the provider     *)
(* holds by then); RequireKnown ignores a finished ceremony while no       *)
(* snapshot exists (today any finished post-open ceremony is the target).  *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS
    Old,                \* sessions on the account before the sheet opens
    Joiners,            \* devices that may consume the code
    SnapshotBeforeCode,
    RequireKnown

ASSUME Old \cap Joiners = {}

Devices == Old \cup Joiners
None == 0
\* A ceremony with d, started before ("pre") or after ("post") the open.
Runners == Devices \X {"pre", "post"}

VARIABLES
    sheet,          \* "closed" or "open"
    code,           \* the handover code is on screen
    roster,         \* the account's sessions, as the homeserver knows them
    viewKnown,      \* the roster provider holds a value
    view,           \* that value
    knownSet,       \* `_knownDeviceIds` has been taken
    known,          \* its contents
    joined,
    ready,
    target,
    presentAtOpen,  \* runners retained by MatrixService when the sheet opened
    outcome,        \* outcome[r]: "none", "pending", "success", "cancelled"
    observed,       \* runners whose success the sheet has handled
    consumedCode,   \* ghost: devices that ever consumed a code from here
    joinedThisOpen  \* ghost: devices that consumed the code shown now

vars == <<sheet, code, roster, viewKnown, view, knownSet, known, joined, ready,
          target, presentAtOpen, outcome, observed, consumedCode,
          joinedThisOpen>>

Init ==
    /\ sheet = "closed"
    /\ code = FALSE
    /\ roster = Old
    /\ viewKnown = FALSE
    /\ view = {}
    /\ knownSet = FALSE
    /\ known = {}
    /\ joined = FALSE
    /\ ready = FALSE
    /\ target = None
    /\ presentAtOpen = {}
    /\ outcome = [r \in Runners |-> "none"]
    /\ observed = {}
    /\ consumedCode = {}
    /\ joinedThisOpen = {}

----------------------------------------------------------------------------
(* The sheet. *)

Open ==
    /\ sheet = "closed"
    /\ sheet' = "open"
    /\ presentAtOpen' = {r \in Runners : outcome[r] # "none"}
    /\ UNCHANGED <<code, roster, viewKnown, view, knownSet, known, joined,
                   ready, target, outcome, observed, consumedCode,
                   joinedThisOpen>>

\* With SnapshotBeforeCode, _generate awaits the roster and records it
\* before the code can be scanned.
ShowCode ==
    /\ sheet = "open"
    /\ ~code
    /\ SnapshotBeforeCode => knownSet
    /\ code' = TRUE
    /\ UNCHANGED <<sheet, roster, viewKnown, view, knownSet, known, joined,
                   ready, target, presentAtOpen, outcome, observed,
                   consumedCode, joinedThisOpen>>

\* The roster provider resolves, or a poll refreshes it. A failed fetch
\* changes nothing and is not modelled.
Fetch ==
    /\ ~viewKnown \/ view # roster
    /\ viewKnown' = TRUE
    /\ view' = roster
    /\ UNCHANGED <<sheet, code, roster, knownSet, known, joined, ready, target,
                   presentAtOpen, outcome, observed, consumedCode,
                   joinedThisOpen>>

\* Today the snapshot is the first roster value seen by a build after the
\* code is up; with the fix, the value _generate awaited before showing it.
Snapshot ==
    /\ sheet = "open"
    /\ viewKnown
    /\ ~knownSet
    /\ code \/ SnapshotBeforeCode
    /\ knownSet' = TRUE
    /\ known' = view
    /\ UNCHANGED <<sheet, code, roster, viewKnown, view, joined, ready, target,
                   presentAtOpen, outcome, observed, consumedCode,
                   joinedThisOpen>>

ObserveRoster ==
    /\ sheet = "open"
    /\ code
    /\ knownSet
    /\ viewKnown
    /\ ~joined
    /\ view \ known # {}
    /\ joined' = TRUE
    /\ UNCHANGED <<sheet, code, roster, viewKnown, view, knownSet, known, ready,
                   target, presentAtOpen, outcome, observed, consumedCode,
                   joinedThisOpen>>

\* A runner the stream emits with a finished, successful ceremony. One
\* retained from before the open — including the incoming stream's replay
\* on listen — is ignored, as is a device already on the snapshot. Without
\* a snapshot the device cannot be told from an old one.
ObserveVerification(r) ==
    /\ sheet = "open"
    /\ outcome[r] = "success"
    /\ r \notin presentAtOpen
    /\ r \notin observed
    /\ ~ready
    /\ observed' = observed \cup {r}
    /\ IF knownSet /\ r[1] \in known
       THEN UNCHANGED <<joined, ready, target>>
       ELSE IF ~knownSet /\ RequireKnown
       THEN UNCHANGED <<joined, ready, target>>
       ELSE /\ joined' = TRUE
            /\ ready' = TRUE
            /\ target' = r[1]
    /\ UNCHANGED <<sheet, code, roster, viewKnown, view, knownSet, known,
                   presentAtOpen, outcome, consumedCode, joinedThisOpen>>

Close ==
    /\ sheet = "open"
    /\ sheet' = "closed"
    /\ code' = FALSE
    /\ knownSet' = FALSE
    /\ known' = {}
    /\ joined' = FALSE
    /\ ready' = FALSE
    /\ target' = None
    /\ presentAtOpen' = {}
    /\ observed' = {}
    /\ joinedThisOpen' = {}
    /\ UNCHANGED <<roster, viewKnown, view, outcome, consumedCode>>

----------------------------------------------------------------------------
(* The environment: the other devices and the SDK. *)

\* A device scans the code, logs in and appears on the roster.
Join(d) ==
    /\ d \in Joiners
    /\ d \notin roster
    /\ code
    /\ roster' = roster \cup {d}
    /\ consumedCode' = consumedCode \cup {d}
    /\ joinedThisOpen' = joinedThisOpen \cup {d}
    /\ UNCHANGED <<sheet, code, viewKnown, view, knownSet, known, joined, ready,
                   target, presentAtOpen, outcome, observed>>

Start(r) ==
    /\ r[1] \in roster
    /\ outcome[r] = "none"
    /\ r[2] = "pre" => sheet = "closed"
    /\ r[2] = "post" => sheet = "open"
    /\ outcome' = [outcome EXCEPT ![r] = "pending"]
    /\ UNCHANGED <<sheet, code, roster, viewKnown, view, knownSet, known, joined,
                   ready, target, presentAtOpen, observed, consumedCode,
                   joinedThisOpen>>

Finish(r, result) ==
    /\ outcome[r] = "pending"
    /\ result \in {"success", "cancelled"}
    /\ outcome' = [outcome EXCEPT ![r] = result]
    /\ UNCHANGED <<sheet, code, roster, viewKnown, view, knownSet, known, joined,
                   ready, target, presentAtOpen, observed, consumedCode,
                   joinedThisOpen>>

----------------------------------------------------------------------------

Next ==
    \/ Open \/ ShowCode \/ Fetch \/ Snapshot \/ ObserveRoster \/ Close
    \/ \E d \in Joiners : Join(d)
    \/ \E r \in Runners :
          \/ Start(r)
          \/ ObserveVerification(r)
          \/ \E result \in {"success", "cancelled"} : Finish(r, result)

\* The sheet's own machinery keeps up; users and peers need not.
Fairness ==
    /\ WF_vars(ShowCode)
    /\ WF_vars(Fetch)
    /\ WF_vars(Snapshot)
    /\ WF_vars(ObserveRoster)
    /\ \A r \in Runners : WF_vars(ObserveVerification(r))

Spec == Init /\ [][Next]_vars /\ Fairness

----------------------------------------------------------------------------
(* Properties. *)

TypeOK ==
    /\ sheet \in {"closed", "open"}
    /\ roster \subseteq Devices
    /\ view \subseteq Devices
    /\ known \subseteq Devices
    /\ target \in Devices \cup {None}
    /\ \A r \in Runners : outcome[r] \in {"none", "pending", "success", "cancelled"}

\* The transfers only ever unlock toward a device that consumed a code from
\* this device — never toward a session that was there all along.
TargetConsumedCode == ready => target \in consumedCode

\* Readiness implies a join, and a verified target.
ReadyIsJoined == ready => joined /\ target # None

\* A device that consumed the code on screen and finished its ceremony while
\* the sheet was open is eventually what the sheet is ready for — unless the
\* sheet was closed first.
EventuallyReady ==
    \A d \in Joiners :
        (sheet = "open" /\ d \in joinedThisOpen /\ outcome[<<d, "post">>] = "success")
            ~> (ready \/ sheet = "closed")
=============================================================================
