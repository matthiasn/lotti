------------------------- MODULE PullRequestSnapshot -------------------------
(***************************************************************************)
(* A GitHub pull request linked to a task: the cached snapshot of it that  *)
(* a journal entry carries, the refreshes that replace that snapshot, the  *)
(* sync that replicates it, and the task contexts (coding prompts, agent   *)
(* checklist suggestions) built from it.                                   *)
(*                                                                         *)
(* The remote pull request changes whenever it likes: a push, a CI result, *)
(* a review, a close, a reopen, a merge. `hist` is a ghost recording what  *)
(* it was at every instant, so the model can check that whatever the app   *)
(* shows was true at the time it says.                                     *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   Request    PullRequestService.refresh, through PullRequestRefresh-   *)
(*              Controller or PullRequestContextService: opening the task, *)
(*              the refresh button, or a context build refreshes a linked, *)
(*              live entry                                                 *)
(*   ReadOk     GitHubClient.fetchPullRequest: the REST reads, stamped     *)
(*              with the server's `Date` header of the pull response       *)
(*   ReadFails  offline, invalid token, rate limited, not found, or no     *)
(*              token on this device: nothing is written                   *)
(*   Persist    PullRequestRepository.persistObservation: writeOnStored    *)
(*              re-reads the stored entry, skips a deleted one, and writes *)
(*              per shouldWritePullRequestObservation, only while the row  *)
(*              it built on is still stored                                *)
(*   Unlink     deleting the entry from the task (a tombstone version)     *)
(*   Receive    JournalDb.updateJournalEntity for this entry type: a newer *)
(*              clock applies, an older one is refused, and a concurrent   *)
(*              one goes to mergeConcurrentPullRequestVersions instead of  *)
(*              the Conflicts screen                                       *)
(*   Build      PullRequestContextService and renderPullRequestContext,   *)
(*              for SkillInferenceRunner (coding prompt) and               *)
(*              TaskAgentWorkflow (wake): the own read unless the stored   *)
(*              one isProvablyLaterObservation; state shown to the agent   *)
(*              only when current                                          *)
(*                                                                         *)
(* An observation's order is its Key: the server stamp, then whether it    *)
(* shows the pull request merged, then a digest of its content. The digest *)
(* only makes the order total, so that every device picks the same winner; *)
(* `Digest` below is deliberately adversarial (it prefers older content).  *)
(*                                                                         *)
(* The mutation switches are TRUE in every checked-in configuration; each  *)
(* names the guard it removes. README.md lists the counterexample TLC      *)
(* finds with each one FALSE.                                              *)
(***************************************************************************)
EXTENDS Naturals, Integers, Sequences, FiniteSets

CONSTANTS
    Devices,        \* devices holding a replica of the entry
    Linker,         \* the device on which the user linked the pull request
    TokenDevices,   \* devices that hold a GitHub token
    JobKinds,       \* subset of {"context", "manual"}: one refresh per kind per device
    MaxTime,        \* bound on ticks of the clock
    MaxRev,         \* bound on pushes (any content change) to the pull request
    Res,            \* server stamp resolution: Stamp(t) = t \div Res
    MaxUnlinks,     \* 0 or 1
    RestampAfter,   \* an unchanged snapshot is rewritten once its stamp is this old
    FetchCanFail,   \* whether a device with a token can still fail a read
    \* mutation switches
    StampAtRead,            \* stamp with the response time, not the write time
    GuardNewer,             \* Persist writes only an observation with a greater Key
    GuardDeleted,           \* Persist skips a deleted entry, and never revives one
    MergedFirst,            \* a merged observation wins a same-stamp tie
    ResolveConcurrent,      \* concurrent versions are merged, not left to the user
    SuggestRequiresRefresh, \* suggestions only after this context's refresh succeeded
    PreferOwnRead           \* a context uses its own read unless the stored one is provably later

ASSUME
    /\ Linker \in Devices
    /\ TokenDevices \subseteq Devices
    /\ JobKinds \subseteq {"context", "manual"}
    /\ Res \in Nat \ {0}
    /\ RestampAfter \in Nat \ {0}

Life == {"open", "closed", "merged"}
Snapshot == [rev : 0..MaxRev, life : Life]
NoSnap == [rev |-> 0, life |-> "none"]

Jobs == Devices \X JobKinds
Pc == {"idle", "requested", "read", "persisted", "failed", "done"}

Stamp(t) == t \div Res

ZeroClock == [d \in Devices |-> 0]

VARIABLES
    now,        \* the clock, in ticks
    hist,       \* ghost: hist[t + 1] is the pull request at tick t
    store,      \* per device: the stored entry
    msgs,       \* sync messages in flight
    pc,         \* per job: progress through the refresh
    startedAt,  \* per job: ghost, the tick at which the refresh was requested
    rsnap,      \* per job: what the read returned
    rtick,      \* per job: ghost, the tick of the read; its stamp is Stamp(rtick)
    basis,      \* per job: the observation this refresh read
    ok,         \* per job: the refresh succeeded on a live entry
    unlinks,
    built       \* ghost: every context built, with what it claimed

vars == <<now, hist, store, msgs, pc, startedAt, rsnap, rtick, basis, ok,
          unlinks, built>>

Remote == hist[now + 1]

-----------------------------------------------------------------------------
(* Ordering observations *)

LifeIdx(l) == CASE l = "none" -> 0 [] l = "open" -> 1
                [] l = "closed" -> 2 [] l = "merged" -> 3

\* Injective and total, and deliberately against recency: it prefers the
\* older revision and the earlier lifecycle state.
Digest(s) == (MaxRev - s.rev) * 4 + (3 - LifeIdx(s.life))

Key(r) == <<r.asOf,
            IF MergedFirst /\ r.snap.life = "merged" THEN 1 ELSE 0,
            Digest(r.snap)>>

LexGt(a, b) ==
    \/ a[1] > b[1]
    \/ a[1] = b[1] /\ a[2] > b[2]
    \/ a[1] = b[1] /\ a[2] = b[2] /\ a[3] > b[3]

Newer(a, b) == LexGt(Key(a), Key(b))

Newest(a, b) == IF Newer(b, a) THEN b ELSE a

-----------------------------------------------------------------------------
(* Vector clocks *)

ClockLeq(a, b) == \A d \in Devices : a[d] <= b[d]
Join(a, b) == [d \in Devices |-> IF a[d] >= b[d] THEN a[d] ELSE b[d]]

-----------------------------------------------------------------------------
(* The stored entry *)

\* `at` is a ghost: the tick at which the stored observation was read.
Absent == [present |-> FALSE, deleted |-> FALSE, snap |-> NoSnap,
           asOf |-> -1, at |-> -1, clock |-> ZeroClock]

Live(r) == r.present /\ ~r.deleted

Send(d, r) == msgs \cup {[to |-> o, rec |-> r] : o \in Devices \ {d}}

\* The concurrent-version resolver: the newest observation, deleted if
\* either side is, under the join of both clocks. Every device that sees the
\* pair computes the same row, so nothing needs to be sent.
Merge(a, b) ==
    [Newest(a, b) EXCEPT !.deleted = a.deleted \/ b.deleted,
                         !.clock = Join(a.clock, b.clock)]

-----------------------------------------------------------------------------

Linked ==
    [present |-> TRUE, deleted |-> FALSE, snap |-> NoSnap, asOf |-> -1,
     at |-> -1, clock |-> [ZeroClock EXCEPT ![Linker] = 1]]

Init ==
    /\ now = 0
    /\ hist = <<[rev |-> 0, life |-> "open"]>>
    /\ store = [d \in Devices |-> IF d = Linker THEN Linked ELSE Absent]
    /\ msgs = {[to |-> o, rec |-> Linked] : o \in Devices \ {Linker}}
    /\ pc = [j \in Jobs |-> "idle"]
    /\ startedAt = [j \in Jobs |-> 0]
    /\ rsnap = [j \in Jobs |-> NoSnap]
    /\ rtick = [j \in Jobs |-> -1]
    /\ basis = [j \in Jobs |-> Absent]
    /\ ok = [j \in Jobs |-> FALSE]
    /\ unlinks = 0
    /\ built = {}

jobVars == <<pc, startedAt, rsnap, rtick, basis, ok>>

-----------------------------------------------------------------------------
(* The world *)

Advance(next) ==
    /\ now < MaxTime
    /\ now' = now + 1
    /\ hist' = Append(hist, next)
    /\ UNCHANGED <<store, msgs, jobVars, unlinks, built>>

Tick == Advance(Remote)

Push ==
    /\ Remote.life = "open" /\ Remote.rev < MaxRev
    /\ Advance([Remote EXCEPT !.rev = @ + 1])

Close == Remote.life = "open" /\ Advance([Remote EXCEPT !.life = "closed"])
Reopen == Remote.life = "closed" /\ Advance([Remote EXCEPT !.life = "open"])
MergePr == Remote.life = "open" /\ Advance([Remote EXCEPT !.life = "merged"])

-----------------------------------------------------------------------------
(* A refresh *)

Request(j) ==
    /\ pc[j] = "idle"
    /\ Live(store[j[1]])
    /\ pc' = [pc EXCEPT ![j] = "requested"]
    /\ startedAt' = [startedAt EXCEPT ![j] = now]
    /\ UNCHANGED <<now, hist, store, msgs, rsnap, rtick, basis, ok, unlinks, built>>

ReadOk(j) ==
    /\ pc[j] = "requested"
    /\ j[1] \in TokenDevices
    /\ pc' = [pc EXCEPT ![j] = "read"]
    /\ rsnap' = [rsnap EXCEPT ![j] = Remote]
    /\ rtick' = [rtick EXCEPT ![j] = now]
    /\ UNCHANGED <<now, hist, store, msgs, startedAt, basis, ok, unlinks, built>>

ReadFails(j) ==
    /\ pc[j] = "requested"
    /\ FetchCanFail \/ j[1] \notin TokenDevices
    /\ pc' = [pc EXCEPT ![j] = "failed"]
    /\ ok' = [ok EXCEPT ![j] = FALSE]
    /\ UNCHANGED <<now, hist, store, msgs, startedAt, rsnap, rtick, basis,
                   unlinks, built>>

\* One transaction: re-read the stored entry, then write or skip. It writes
\* only a changed snapshot, or the same one once the stored stamp is
\* RestampAfter old: every write notifies the task, and a write on every
\* refresh would wake the task agent whose context started the refresh.
\* Written or not, the observation is what the context starts from.
Persist(j) ==
    LET d == j[1]
        s == store[d]
        obs == [s EXCEPT !.snap = rsnap[j],
                         !.asOf = IF StampAtRead THEN Stamp(rtick[j]) ELSE Stamp(now),
                         !.at = rtick[j],
                         !.deleted = IF GuardDeleted THEN @ ELSE FALSE,
                         !.clock[d] = @ + 1]
        changed == \/ obs.snap # s.snap
                   \/ s.asOf < 0
                   \/ obs.asOf - s.asOf >= RestampAfter
        writes == /\ s.present
                  /\ ~s.deleted \/ ~GuardDeleted
                  /\ Newer(obs, s) \/ ~GuardNewer
                  /\ changed
    IN
    /\ pc[j] = "read"
    /\ pc' = [pc EXCEPT ![j] = "persisted"]
    /\ IF writes
       THEN /\ store' = [store EXCEPT ![d] = obs]
            /\ msgs' = Send(d, obs)
       ELSE UNCHANGED <<store, msgs>>
    /\ ok' = [ok EXCEPT ![j] = writes \/ Live(s)]
    /\ basis' = [basis EXCEPT ![j] = obs]
    /\ UNCHANGED <<now, hist, startedAt, rsnap, rtick, unlinks, built>>

\* A stored observation the context may use instead of its own read: one
\* provably read later. A later stamp is; so is a merged one in the same
\* second as an unmerged read, because a merge is final. Within one second
\* the Key's digest says nothing about time, so the newest by Key can be a
\* read made before the request.
LaterThan(st, own) ==
    \/ st.asOf > own.asOf
    \/ /\ st.asOf = own.asOf
       /\ st.snap.life = "merged" /\ own.snap.life # "merged"

\* The context reads the entry again: it may have been unlinked, or a later
\* observation may have synced in, since the refresh finished.
Build(j) ==
    LET d == j[1]
        s == store[d]
        refreshed == pc[j] = "persisted" /\ ok[j] /\ Live(s)
        own == basis[j]
        use == IF ~refreshed THEN s
               ELSE IF PreferOwnRead
                    THEN IF LaterThan(s, own) THEN s ELSE own
                    ELSE Newest(own, s)
        suggest == IF SuggestRequiresRefresh THEN refreshed ELSE TRUE
    IN
    /\ j[2] = "context"
    /\ pc[j] \in {"persisted", "failed"}
    /\ pc' = [pc EXCEPT ![j] = "done"]
    /\ built' = IF Live(s) /\ use.asOf >= 0
                THEN built \cup {[startedAt |-> startedAt[j], asOf |-> use.asOf,
                                  at |-> use.at,
                                  snap |-> use.snap, current |-> refreshed,
                                  suggest |-> suggest]}
                ELSE built
    /\ UNCHANGED <<now, hist, store, msgs, startedAt, rsnap, rtick, basis, ok,
                   unlinks>>

Finish(j) ==
    /\ j[2] = "manual"
    /\ pc[j] \in {"persisted", "failed"}
    /\ pc' = [pc EXCEPT ![j] = "done"]
    /\ UNCHANGED <<now, hist, store, msgs, startedAt, rsnap, rtick, basis, ok,
                   unlinks, built>>

-----------------------------------------------------------------------------
(* The user and sync *)

Unlink(d) ==
    /\ unlinks < MaxUnlinks
    /\ Live(store[d])
    /\ LET r == [store[d] EXCEPT !.deleted = TRUE, !.clock[d] = @ + 1]
       IN /\ store' = [store EXCEPT ![d] = r]
          /\ msgs' = Send(d, r)
    /\ unlinks' = unlinks + 1
    /\ UNCHANGED <<now, hist, jobVars, built>>

Receive(m) ==
    LET d == m.to
        s == store[d]
        in == m.rec
    IN
    /\ m \in msgs
    /\ msgs' = msgs \ {m}
    /\ store' =
         [store EXCEPT ![d] =
            IF ~s.present THEN in
            ELSE IF ClockLeq(in.clock, s.clock) THEN s
            ELSE IF ClockLeq(s.clock, in.clock) THEN in
            ELSE IF ResolveConcurrent THEN Merge(s, in)
            ELSE s]
    /\ UNCHANGED <<now, hist, jobVars, unlinks, built>>

-----------------------------------------------------------------------------

Next ==
    \/ Tick \/ Push \/ Close \/ Reopen \/ MergePr
    \/ \E j \in Jobs :
          Request(j) \/ ReadOk(j) \/ ReadFails(j) \/ Persist(j)
          \/ Build(j) \/ Finish(j)
    \/ \E d \in Devices : Unlink(d)
    \/ \E m \in msgs : Receive(m)

\* A started refresh runs to its end and every message is delivered; nobody
\* is forced to request a refresh, and the remote need not change.
Fairness ==
    /\ \A j \in Jobs :
          /\ WF_vars(ReadOk(j) \/ ReadFails(j))
          /\ WF_vars(Persist(j))
          /\ WF_vars(Build(j) \/ Finish(j))
    /\ WF_vars(\E m \in msgs : Receive(m))

Spec == Init /\ [][Next]_vars /\ Fairness

-----------------------------------------------------------------------------
(* What the user sees of the entry on one device *)

Fetching(d) == \E k \in JobKinds : pc[<<d, k>>] \in {"requested", "read"}

View(d) ==
    LET s == store[d] IN
    CASE ~s.present          -> "absent"
      [] s.deleted           -> "unlinked"
      [] Fetching(d)         -> "fetching"
      [] s.asOf < 0          -> "linked"
      [] OTHER               -> s.snap.life   \* open, closed or merged, as of s.asOf

-----------------------------------------------------------------------------
(* Properties *)

StoreRec == [present : BOOLEAN, deleted : BOOLEAN,
             snap : Snapshot \cup {NoSnap}, asOf : -1..MaxTime,
             at : -1..MaxTime,
             clock : [Devices -> Nat]]

TypeOK ==
    /\ now \in 0..MaxTime
    /\ Len(hist) = now + 1
    /\ store \in [Devices -> StoreRec]
    /\ pc \in [Jobs -> Pc]
    /\ unlinks \in 0..MaxUnlinks

\* The pull request really was in that state at some instant carrying the
\* stamp the entry shows: nothing is ever labelled with a time at which it
\* was not true.
HonestAt(snap, asOf) ==
    \E t \in 0..now : Stamp(t) = asOf /\ hist[t + 1] = snap

SnapshotHonest ==
    \A d \in Devices : store[d].asOf >= 0 => HonestAt(store[d].snap, store[d].asOf)

\* What a context claimed was true when it claimed it, and a context only
\* calls the pull request current when it was read after the request — at
\* the instant, not merely within the same second of `Date`.
ContextHonest ==
    \A c \in built :
        /\ HonestAt(c.snap, c.asOf)
        /\ c.current => c.at >= c.startedAt

\* Checklist suggestions are derived only from a snapshot observed after the
\* context was requested, by a refresh that succeeded.
SuggestionsFromRefreshed ==
    \A c \in built : c.suggest => (c.current /\ c.at >= c.startedAt)

\* A version with a newer clock never carries an older observation: so the
\* clock order sync already applies agrees with the observation order.
NewerClockNeverOlderData ==
    \A m \in msgs :
        LET s == store[m.to] IN
        (s.present /\ ClockLeq(s.clock, m.rec.clock) /\ s.clock # m.rec.clock)
            => ~Newer(s, m.rec)

\* With nothing in flight, every replica holds the same entry.
Converged ==
    msgs = {} =>
        \A a, b \in Devices :
            /\ store[a].deleted = store[b].deleted
            /\ store[a].snap = store[b].snap
            /\ store[a].asOf = store[b].asOf

\* No device ever shows a merged pull request as open again, nor an older
\* observation after a newer one, nor loses its snapshot.
NoRegression ==
    [][\A d \in Devices :
          LET s == store[d] IN
          /\ s.snap.life = "merged" => store'[d].snap.life = "merged"
          /\ s.asOf <= store'[d].asOf
          /\ s.present => store'[d].present]_vars

\* An unlinked entry stays unlinked.
UnlinkIsFinal ==
    [][\A d \in Devices : store[d].deleted => store'[d].deleted]_vars

\* Every requested refresh ends.
RefreshesEnd == \A j \in Jobs : pc[j] = "requested" ~> pc[j] = "done"

\* Replication settles.
SyncSettles == <>[](msgs = {})
=============================================================================
