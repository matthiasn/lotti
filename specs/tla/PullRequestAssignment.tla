----------------------- MODULE PullRequestAssignment -----------------------
(***************************************************************************)
(* Which tasks a GitHub pull request is linked to (a design model).        *)
(*                                                                         *)
(* A pull request may serve more than one task, but only on purpose. The   *)
(* "+" picker on a task lists the repository's open pull requests minus    *)
(* those this device already holds linked to a task; pasting a URL lists   *)
(* nothing and links what was pasted. Either way the link is decided when  *)
(* the user commits to it, and the list a picker shows can be stale by     *)
(* then: another session on the device, or sync, may have linked the pull *)
(* request since. A pull request this task holds is refused; one another   *)
(* task holds is not linked silently but asked about — the user confirms   *)
(* linking it here as well, or declines.                                   *)
(*                                                                         *)
(* Two devices that link the same pull request to different tasks before  *)
(* they sync cannot see each other. Nothing local can prevent that, so the *)
(* model asks for the next best thing: a double assignment comes from two  *)
(* devices or from a confirmation, never silently from one device, and     *)
(* every device ends up holding the same assignments, so they all show the *)
(* same ones.                                                              *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   List       the picker's list (PullRequestService.openPullRequests:    *)
(*              GitHub's open pull requests minus the held ones), or a     *)
(*              pasted URL                                                 *)
(*   Choose     PullRequestService.link → PullRequestRepository.link: the  *)
(*              re-check and the entry's creation under one per-device     *)
(*              lock; held by another task, it answers                     *)
(*              PullRequestLinkedElsewhere instead of linking              *)
(*   Confirm    the link modal's "link here too", which links again with   *)
(*              alsoElsewhere: the same lock, re-checking only this task   *)
(*   Decline    the modal's cancel on that question                        *)
(*   Create     the creation, when it is a step of its own (AtomicLink off)*)
(*   Unlink     PullRequestRepository.unlink: this task's entries only     *)
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
    RecheckAtLink,        \* the link re-checks what the device holds when committed
    AtomicLink,           \* ...and creates the entry in the same step
    ConfirmElsewhere,     \* one another task holds is asked about, not linked
    RecheckAtConfirm,     \* the confirmation re-checks that this task does not hold it
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
    created,   \* ghost: every creation, with what its device held and whether it was confirmed
    unlinks

vars == <<store, counter, msgs, session, created, unlinks>>

Holding(d, p) == {e.task : e \in {x \in store[d] : x.pr = p /\ x.live}}
Assigned(d, p) == Holding(d, p) # {}

Idle == [phase |-> "idle", task |-> CHOOSE t \in Tasks : TRUE,
         shown |-> {}, pr |-> CHOOSE p \in PullRequests : TRUE,
         confirmed |-> FALSE]

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
         [phase |-> "listed", task |-> t, pr |-> @.pr, confirmed |-> FALSE,
          shown |-> IF paste \/ ~PickerFilters
                    THEN PullRequests
                    ELSE {p \in PullRequests : ~Assigned(d, p)}]]
    /\ UNCHANGED <<store, counter, msgs, created, unlinks>>

\* Creates the entry, recording what the device held at that moment: whether
\* this task held the pull request already, and whether another task did.
CreateEntry(s, p, confirmed) ==
    LET d == s[1]
        t == session[s].task
        e == [id |-> <<d, counter[d]>>, pr |-> p, task |-> t, live |-> TRUE]
    IN
    /\ Cardinality(created) < MaxLinks
    /\ store' = [store EXCEPT ![d] = @ \cup {e}]
    /\ counter' = [counter EXCEPT ![d] = @ + 1]
    /\ msgs' = Send(d, e)
    /\ created' = created \cup
         {[entry |-> e, own |-> t \in Holding(d, p),
           others |-> Holding(d, p) \ {t} # {}, confirmed |-> confirmed]}
    /\ session' = [session EXCEPT ![s] = Idle]

\* Creates now (AtomicLink) or in a later Create step.
Commit(s, p, confirmed) ==
    IF AtomicLink
    THEN CreateEntry(s, p, confirmed)
    ELSE /\ session' = [session EXCEPT ![s].phase = "checked", ![s].pr = p,
                                       ![s].confirmed = confirmed]
         /\ UNCHANGED <<store, counter, msgs, created>>

\* The user commits to pull request p, picked or pasted. Re-checked against
\* what the device holds now, not when the list was shown: held by this task
\* it is refused; held by another it is asked about; otherwise linked.
Choose(s, p) ==
    LET d == s[1]
        t == session[s].task
    IN
    /\ session[s].phase = "listed"
    /\ p \in session[s].shown
    /\ IF RecheckAtLink /\ t \in Holding(d, p)
       THEN /\ session' = [session EXCEPT ![s] = Idle]
            /\ UNCHANGED <<store, counter, msgs, created>>
       ELSE IF RecheckAtLink /\ ConfirmElsewhere /\ Assigned(d, p)
       THEN /\ session' = [session EXCEPT ![s].phase = "asked", ![s].pr = p]
            /\ UNCHANGED <<store, counter, msgs, created>>
       ELSE Commit(s, p, FALSE)
    /\ UNCHANGED unlinks

\* The user confirms linking a pull request another task holds. Re-checked
\* again: this task may have got it meanwhile, from another session or sync.
\* Another task holding it is what the user just accepted.
Confirm(s) ==
    LET d == s[1]
        p == session[s].pr
    IN
    /\ session[s].phase = "asked"
    /\ IF RecheckAtConfirm /\ session[s].task \in Holding(d, p)
       THEN /\ session' = [session EXCEPT ![s] = Idle]
            /\ UNCHANGED <<store, counter, msgs, created>>
       ELSE Commit(s, p, TRUE)
    /\ UNCHANGED unlinks

Decline(s) ==
    /\ session[s].phase = "asked"
    /\ session' = [session EXCEPT ![s] = Idle]
    /\ UNCHANGED <<store, counter, msgs, created, unlinks>>

\* Only without AtomicLink: the creation a check above let through.
Create(s) ==
    /\ session[s].phase = "checked"
    /\ CreateEntry(s, session[s].pr, session[s].confirmed)
    /\ UNCHANGED unlinks

Cancel(s) ==
    /\ session[s].phase = "listed"
    /\ session' = [session EXCEPT ![s] = Idle]
    /\ UNCHANGED <<store, counter, msgs, created, unlinks>>

\* Unlinking from a task deletes that task's entry; another task's entry of
\* the same pull request is a different entry and stays.
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
    \/ \E s \in Sessions : Confirm(s) \/ Decline(s) \/ Create(s) \/ Cancel(s)
    \/ \E d \in Devices : \E e \in store[d] : Unlink(d, e)
    \/ \E m \in msgs : Receive(m)

Spec == Init /\ [][Next]_vars

-----------------------------------------------------------------------------

TypeOK ==
    /\ \A d \in Devices : store[d] \subseteq Entry
    /\ counter \in [Devices -> Nat]

\* No device links a pull request to a task that already holds it, however
\* stale the picker's list or however many prompts are open.
NoSameTaskDuplicate == \A c \in created : ~c.own

\* A device links a pull request another task holds only once the user has
\* confirmed it: a stale list or a racing session never does it silently.
NoUnconfirmedLocalDoubleAssignment ==
    \A c \in created : c.others => c.confirmed

Confirmed(e) == \E c \in created : c.entry.id = e.id /\ c.confirmed

\* So once sync has settled, a pull request held by two tasks was linked to
\* them by two different devices — before either saw the other's link — or
\* the user confirmed one of the links.
\* Only once settled: sync does not deliver a device's entries in order, so a
\* pull request moved from one task to another can arrive before the unlink
\* that preceded it, and be held twice until that unlink arrives too.
DoubleAssignmentOnlyAcrossDevicesOrConfirmed ==
    msgs = {} =>
        \A d \in Devices : \A a, b \in store[d] :
            (a.live /\ b.live /\ a.pr = b.pr /\ a.task # b.task)
                => (a.id[1] # b.id[1] \/ Confirmed(a) \/ Confirmed(b))

\* With nothing in flight, every device holds the same entries: they show the
\* same assignments and their pickers leave out the same pull requests.
Converged == msgs = {} => \A a, b \in Devices : store[a] = store[b]
=============================================================================
