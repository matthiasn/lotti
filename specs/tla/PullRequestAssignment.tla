----------------------- MODULE PullRequestAssignment -----------------------
(***************************************************************************)
(* Which task a GitHub pull request belongs to (a design model).           *)
(*                                                                         *)
(* A pull request belongs to one task. The "+" picker on a task lists the  *)
(* repository's open pull requests minus those this device already holds  *)
(* linked to a task; pasting a URL lists nothing and links what was        *)
(* pasted. Either way the link is decided when the user commits to it, and *)
(* the list a picker shows can be stale by then: another session on the   *)
(* device, or sync, may have linked the pull request since.                *)
(*                                                                         *)
(* Two devices that link the same pull request to different tasks before  *)
(* they sync cannot see each other. Nothing local can prevent that, so the *)
(* model asks for the next best thing: a double assignment only ever comes *)
(* from two devices, never from one, and every device ends up holding the  *)
(* same assignments, so they all flag the same conflict and exclude the    *)
(* same pull requests until the user unlinks one.                          *)
(*                                                                         *)
(* What is modelled, and where it will live in the Dart code:              *)
(*                                                                         *)
(*   List       the picker's list (GitHubClient.listOpenPullRequests minus *)
(*              PullRequestRepository's assignments), or a pasted URL      *)
(*   Choose     PullRequestRepository.link: the assignment re-check and    *)
(*              the entry's creation, under one per-device lock            *)
(*   Create     the creation, when it is a step of its own (AtomicLink off)*)
(*   Unlink     PullRequestRepository.unlink                               *)
(*   Receive    sync of the pull request entries: every entry is kept, a   *)
(*              deletion wins                                              *)
(*                                                                         *)
(* Every switch is TRUE in the checked-in configurations; README.md lists  *)
(* the counterexample each has when FALSE.                                 *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS
    Devices,
    SessionsPerDevice,   \* concurrent pickers or pastes on one device
    PullRequests,
    Tasks,
    MaxLinks,            \* bound on assignments created
    MaxUnlinks,
    \* design switches
    PickerFilters,        \* the picker leaves out pull requests already held
    RecheckAtLink,        \* the link re-checks the assignment when committed
    AtomicLink,           \* ...and creates the entry in the same step
    KeepIncomingConflict  \* sync keeps an entry that conflicts with a local one

ASSUME SessionsPerDevice \in Nat \ {0}

Sessions == Devices \X (1..SessionsPerDevice)

\* An assignment entry. `id` is unique: the creating device and a counter.
Entry == [id : Devices \X Nat, pr : PullRequests, task : Tasks, live : BOOLEAN]

VARIABLES
    store,     \* per device: the entries it holds
    counter,   \* per device: the next entry number
    msgs,      \* entries in flight to other devices
    session,   \* per session: progress of one pick or paste
    created,   \* ghost: every creation, with whether its device already held the pull request
    unlinks

vars == <<store, counter, msgs, session, created, unlinks>>

Holding(d, p) == {e.task : e \in {x \in store[d] : x.pr = p /\ x.live}}
Assigned(d, p) == Holding(d, p) # {}

Idle == [phase |-> "idle", task |-> CHOOSE t \in Tasks : TRUE,
         shown |-> {}, pr |-> CHOOSE p \in PullRequests : TRUE]

Init ==
    /\ store = [d \in Devices |-> {}]
    /\ counter = [d \in Devices |-> 0]
    /\ msgs = {}
    /\ session = [s \in Sessions |-> Idle]
    /\ created = {}
    /\ unlinks = 0

Send(d, e) == msgs \cup {[to |-> o, entry |-> e] : o \in Devices \ {d}}

\* Open the picker on a task (filtered list), or paste a URL (no list).
List(s, t, paste) ==
    LET d == s[1] IN
    /\ session[s].phase = "idle"
    /\ session' = [session EXCEPT ![s] =
         [phase |-> "listed", task |-> t, pr |-> @.pr,
          shown |-> IF paste \/ ~PickerFilters
                    THEN PullRequests
                    ELSE {p \in PullRequests : ~Assigned(d, p)}]]
    /\ UNCHANGED <<store, counter, msgs, created, unlinks>>

CreateEntry(s, p) ==
    LET d == s[1]
        e == [id |-> <<d, counter[d]>>, pr |-> p, task |-> session[s].task,
              live |-> TRUE]
    IN
    /\ Cardinality(created) < MaxLinks
    /\ store' = [store EXCEPT ![d] = @ \cup {e}]
    /\ counter' = [counter EXCEPT ![d] = @ + 1]
    /\ msgs' = Send(d, e)
    /\ created' = created \cup {[entry |-> e, held |-> Assigned(d, p)]}
    /\ session' = [session EXCEPT ![s] = Idle]

\* The user commits to pull request p. Re-checked against what the device
\* holds now, not when the list was shown; refused when already held.
Choose(s, p) ==
    LET d == s[1] IN
    /\ session[s].phase = "listed"
    /\ p \in session[s].shown
    /\ IF RecheckAtLink /\ Assigned(d, p)
       THEN /\ session' = [session EXCEPT ![s] = Idle]
            /\ UNCHANGED <<store, counter, msgs, created>>
       ELSE IF AtomicLink
            THEN CreateEntry(s, p)
            ELSE /\ session' = [session EXCEPT ![s].phase = "checked",
                                                ![s].pr = p]
                 /\ UNCHANGED <<store, counter, msgs, created>>
    /\ UNCHANGED unlinks

\* Only without AtomicLink: the creation the check above let through.
Create(s) ==
    /\ session[s].phase = "checked"
    /\ CreateEntry(s, session[s].pr)
    /\ UNCHANGED unlinks

Cancel(s) ==
    /\ session[s].phase = "listed"
    /\ session' = [session EXCEPT ![s] = Idle]
    /\ UNCHANGED <<store, counter, msgs, created, unlinks>>

Unlink(d, e) ==
    /\ unlinks < MaxUnlinks
    /\ e \in store[d]
    /\ e.live
    /\ LET dead == [e EXCEPT !.live = FALSE] IN
       /\ store' = [store EXCEPT ![d] = (@ \ {e}) \cup {dead}]
       /\ msgs' = Send(d, dead)
    /\ unlinks' = unlinks + 1
    /\ UNCHANGED <<counter, session, created>>

\* Sync of one entry. A deletion wins over the live copy of the same entry.
Receive(m) ==
    LET d == m.to
        e == m.entry
        same == {x \in store[d] : x.id = e.id}
        conflicting == e.live /\ \E t \in Holding(d, e.pr) : t # e.task
        keep == KeepIncomingConflict \/ ~conflicting \/ same # {}
    IN
    /\ m \in msgs
    /\ msgs' = msgs \ {m}
    /\ store' = [store EXCEPT ![d] =
         IF ~keep THEN @
         ELSE IF same = {} THEN @ \cup {e}
         ELSE IF e.live THEN @
         ELSE (@ \ same) \cup {e}]
    /\ UNCHANGED <<counter, session, created, unlinks>>

Next ==
    \/ \E s \in Sessions, t \in Tasks, paste \in BOOLEAN : List(s, t, paste)
    \/ \E s \in Sessions, p \in PullRequests : Choose(s, p)
    \/ \E s \in Sessions : Create(s) \/ Cancel(s)
    \/ \E d \in Devices : \E e \in store[d] : Unlink(d, e)
    \/ \E m \in msgs : Receive(m)

Spec == Init /\ [][Next]_vars

-----------------------------------------------------------------------------

TypeOK ==
    /\ \A d \in Devices : store[d] \subseteq Entry
    /\ counter \in [Devices -> Nat]

\* No device links a pull request it already holds: the picker's list may be
\* stale and a paste lists nothing, so this is the link's own guarantee.
NoLocalDoubleAssignment == \A c \in created : ~c.held

\* So once sync has settled, a pull request held by two tasks was linked to
\* them by two different devices, before either saw the other's link.
\* Only once settled: sync does not deliver a device's entries in order, so a
\* pull request moved from one task to another can arrive before the unlink
\* that preceded it, and be held twice until that unlink arrives too — the
\* first counterexample TLC found for this property without the guard.
DoubleAssignmentOnlyAcrossDevices ==
    msgs = {} =>
        \A d \in Devices : \A a, b \in store[d] :
            (a.live /\ b.live /\ a.pr = b.pr /\ a.task # b.task)
                => a.id[1] # b.id[1]

\* With nothing in flight, every device holds the same entries: they flag the
\* same double assignments and their pickers leave out the same pull requests.
Converged == msgs = {} => \A a, b \in Devices : store[a] = store[b]
=============================================================================
