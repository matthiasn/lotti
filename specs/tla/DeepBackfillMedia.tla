-------------------------- MODULE DeepBackfillMedia --------------------------
(***************************************************************************)
(* Deep backfill for media: the files behind image and audio entries.     *)
(*                                                                         *)
(* DeepBackfill.tla brings every device the same record versions, and a  *)
(* record a device held no row for travels with its file. What it cannot  *)
(* see is a record both devices hold at the same version while one lacks  *)
(* the file, or holds a truncated copy: equal clocks, nothing requested,  *)
(* nothing pushed. This module adds the file to the round:                 *)
(*                                                                         *)
(*   1. The inventory lists, per record, the size of the advertiser's     *)
(*      file (0: none) next to the clock (EmitBatch).                      *)
(*   2. A recipient holding a smaller file asks the advertiser for it; a  *)
(*      recipient holding a larger one pushes it back (Diff).             *)
(*   3. The advertiser answers with its current file, whatever the        *)
(*      resend-attachments setting says (Answer).                         *)
(*   4. A received file replaces the local one only when it is larger    *)
(*      (Receive): a truncated copy never overwrites a whole one, and a   *)
(*      truncated local copy is not taken for a whole one.                *)
(*                                                                         *)
(* A file is its size: files are written once, at the entry's creation,   *)
(* and a copy can only lose bytes (an interrupted transfer, a lost file). *)
(* Content corruption at the same size is out of scope: sizes only, no    *)
(* hashing of every file on every round. `Truncate` is that loss, the     *)
(* fault the protocol repairs, bounded by `MaxFaults`.                     *)
(*                                                                         *)
(* Every device holds the row of every record, live: the record protocol  *)
(* of DeepBackfill.tla is assumed done. (A row absent on one side travels *)
(* with its file there; a tombstone carries no media claim.)              *)
(*                                                                         *)
(* The design switches; TRUE is the design, and each one set to FALSE has *)
(* a counterexample (README):                                              *)
(*   AdvertiseMedia     the inventory carries each record's file size      *)
(*   ReplaceShorter     a receive replaces a smaller non-empty local file  *)
(*   NeverShrink        ...but never with a smaller one                    *)
(*   AnswerIgnoresFlag  an answer carries the file even with resending of  *)
(*                      attachments switched off                           *)
(*   DedupeOutstanding  no request for a file already requested            *)
(*                                                                         *)
(* Where each action lives in the Dart code:                               *)
(*                                                                         *)
(*   EmitBatch   DeepBackfillService.runRound, sizes read by the journal  *)
(*               store (DeepBackfillRecord.mediaSize)                      *)
(*   Diff        diffDeepBackfillBatch: mediaRequests, mediaPushes         *)
(*   Answer      DeepBackfillService.handleRequest, a record flagged      *)
(*               `media`, enqueued with includeAttachments                *)
(*   Receive     AttachmentIngestor._saveAttachment against the event's   *)
(*               declared size                                             *)
(*   Settles     DeepBackfillService._settleOutstanding: the request row  *)
(*               records the size asked for                                *)
(***************************************************************************)
EXTENDS Integers, FiniteSets

CONSTANTS
    N,            \* devices 1..N
    NI,           \* records 1..NI, one per batch
    Full,         \* a whole file's size; a copy holds 0..Full
    Runners,      \* devices whose user runs maintenance
    Resend,       \* resending attachments is switched on: ordinary sync
                  \* may carry any device's file, whole or not
    LossBudget,   \* messages the network may lose
    MaxCrashes,   \* device crashes
    MaxFaults,    \* files truncated or lost after the start
    \* Design switches: TRUE is the design.
    AdvertiseMedia,
    ReplaceShorter,
    NeverShrink,
    AnswerIgnoresFlag,
    DedupeOutstanding

R == 1..N
Ids == 1..NI
Sizes == 0..Full

ASSUME N \in Nat /\ N >= 2 /\ NI \in Nat /\ NI >= 1 /\ Full \in Nat /\ Full >= 1
ASSUME LossBudget \in Nat /\ MaxCrashes \in Nat /\ MaxFaults \in Nat
ASSUME Runners \subseteq R /\ Runners # {}
ASSUME \A b \in {Resend, AdvertiseMedia, ReplaceShorter, NeverShrink,
                 AnswerIgnoresFlag, DedupeOutstanding} : b \in BOOLEAN

\* Messages; every one has the same fields so TLC can compare them.
\*   inv: `from` advertises record `i` to `to`, its file of `size`
\*        (AdvertiseMedia) -- or no size at all, as a peer without it does
\*   req: `from` asks `to` for the file of record `i`, `size` the size it
\*        was advertised with (a ghost: the wire carries the id and a flag)
\*   pay: `from` sends `to` its file of record `i`, `size` bytes -- an
\*        answer (`ans`), a push, or ordinary sync; the same journal entry
\*        message with its attachment on the wire
Msg(t, f, to, i, s, a) ==
    [type |-> t, from |-> f, to |-> to, i |-> i, size |-> s, ans |-> a]
NoSize == -1

VARIABLES
    file,     \* per device, per record: the size of the local copy
    rnd,      \* per device: 0 idle, else the next record to advertise
    net,      \* messages enqueued or in the room, not yet consumed
    out,      \* per device: outstanding requests <<advertiser, id, size>>
    losses,   \* messages lost so far
    crashes,  \* crashes so far
    faults    \* truncations so far

vars == <<file, rnd, net, out, losses, crashes, faults>>

\* Each copy starts anywhere between missing and whole: an installation
\* whose files were lost or cut short in arbitrary places.
Init ==
    /\ file \in [R -> [Ids -> Sizes]]
    /\ rnd = [r \in R |-> 0]
    /\ net = {}
    /\ out = [r \in R |-> {}]
    /\ losses = 0
    /\ crashes = 0
    /\ faults = 0

\* The largest copy of record i anywhere: what every device should end with.
Best(i) == CHOOSE s \in {file[r][i] : r \in R} :
               \A r \in R : file[r][i] <= s

(***************************************************************************)
(* The round.                                                              *)
(***************************************************************************)
\* As in DeepBackfill.tla: the next round starts once the last one's
\* batches were read -- a bound on the state space, not a rule.
StartRound(r) ==
    /\ r \in Runners
    /\ rnd[r] = 0
    /\ ~\E m \in net : m.type = "inv" /\ m.from = r
    /\ rnd' = [rnd EXCEPT ![r] = 1]
    /\ UNCHANGED <<file, net, out, losses, crashes, faults>>

EmitBatch(r) ==
    /\ rnd[r] # 0
    /\ LET i == rnd[r]
           s == IF AdvertiseMedia THEN file[r][i] ELSE NoSize
       IN /\ net' = net \cup {Msg("inv", r, e, i, s, FALSE) : e \in R \ {r}}
          /\ rnd' = [rnd EXCEPT ![r] = IF i = NI THEN 0 ELSE i + 1]
    /\ UNCHANGED <<file, out, losses, crashes, faults>>

\* A peer that advertises no size is never asked for its file, and never
\* sent one: the clocks are equal, and nothing says a file is missing.
Diff(e, m) ==
    /\ m \in net /\ m.type = "inv" /\ m.to = e
    /\ LET d == m.from
           i == m.i
           mine == file[e][i]
           need == /\ m.size # NoSize
                   /\ m.size > mine
                   /\ ~DedupeOutstanding
                      \/ ~\E x \in out[e] : x[1] = d /\ x[2] = i
           owe == m.size # NoSize /\ mine > m.size
       IN /\ net' = (net \ {m})
                    \cup (IF need THEN {Msg("req", e, d, i, m.size, FALSE)}
                          ELSE {})
                    \cup (IF owe THEN {Msg("pay", e, d, i, mine, FALSE)}
                          ELSE {})
          /\ out' = IF need THEN [out EXCEPT ![e] = @ \cup {<<d, i, m.size>>}]
                    ELSE out
    /\ UNCHANGED <<file, rnd, losses, crashes, faults>>

\* The advertiser answers with the file it holds now, which may have been
\* cut short since it advertised it. A missing file sends no attachment
\* (the payload sender skips it); the entry itself changes nothing here.
Answer(d, m) ==
    /\ m \in net /\ m.type = "req" /\ m.to = d
    /\ LET s == file[d][m.i]
           carries == (AnswerIgnoresFlag \/ Resend) /\ s > 0
       IN net' = (net \ {m})
                 \cup (IF carries THEN {Msg("pay", d, m.from, m.i, s, TRUE)}
                       ELSE {})
    /\ UNCHANGED <<file, rnd, out, losses, crashes, faults>>

\* Ordinary sync with resending switched on: any device may send its copy
\* of any record, whole or not, to everyone.
ResendFile(r, i) ==
    /\ Resend
    /\ file[r][i] > 0
    /\ net' = net \cup {Msg("pay", r, e, i, file[r][i], FALSE) : e \in R \ {r}}
    /\ UNCHANGED <<file, rnd, out, losses, crashes, faults>>

\* The receive decision. Today's: an existing non-empty file is kept.
\* The design: replace a smaller copy, never with a smaller one.
Writes(mine, s) ==
    IF ~ReplaceShorter THEN mine = 0
    ELSE IF NeverShrink THEN s > mine
    ELSE TRUE

\* A request is settled once the local copy is at least the size asked
\* for, whoever sent it.
Receive(e, m) ==
    /\ m \in net /\ m.type = "pay" /\ m.to = e
    /\ LET i == m.i
           now == IF Writes(file[e][i], m.size) THEN m.size ELSE file[e][i]
       IN /\ file' = [file EXCEPT ![e][i] = now]
          /\ out' = [out EXCEPT ![e] = {x \in @ : ~(x[2] = i /\ now >= x[3])}]
    /\ net' = net \ {m}
    /\ UNCHANGED <<rnd, losses, crashes, faults>>

\* A request, or its answer, is gone: the requester's timeout frees the
\* record for the next round.
InFlight(e, x) ==
    \E m \in net : \/ m.type = "req" /\ m.from = e /\ m.to = x[1]
                      /\ m.i = x[2]
                   \/ m.type = "pay" /\ m.ans /\ m.from = x[1] /\ m.to = e
                      /\ m.i = x[2]
Expire(e, x) ==
    /\ x \in out[e]
    /\ ~InFlight(e, x)
    /\ out' = [out EXCEPT ![e] = @ \ {x}]
    /\ UNCHANGED <<file, rnd, net, losses, crashes, faults>>

\* A file loses bytes or disappears: the fault being repaired.
Truncate(r, i) ==
    /\ faults < MaxFaults
    /\ file[r][i] > 0
    /\ \E s \in 0..(file[r][i] - 1) : file' = [file EXCEPT ![r][i] = s]
    /\ faults' = faults + 1
    /\ UNCHANGED <<rnd, net, out, losses, crashes>>

Lose(m) ==
    /\ losses < LossBudget
    /\ m \in net
    /\ net' = net \ {m}
    /\ losses' = losses + 1
    /\ UNCHANGED <<file, rnd, out, crashes, faults>>

\* The files, the outbox and the outstanding requests (a table) survive;
\* the round's progress does not.
Crash(r) ==
    /\ crashes < MaxCrashes
    /\ crashes' = crashes + 1
    /\ rnd' = [rnd EXCEPT ![r] = 0]
    /\ UNCHANGED <<file, net, out, losses, faults>>

Next ==
    \/ \E r \in R : StartRound(r) \/ EmitBatch(r) \/ Crash(r)
    \/ \E r \in R, i \in Ids : ResendFile(r, i) \/ Truncate(r, i)
    \/ \E m \in net : Diff(m.to, m) \/ Answer(m.to, m) \/ Receive(m.to, m)
                      \/ Lose(m)
    \/ \E e \in R : \E x \in out[e] : Expire(e, x)

Fairness ==
    /\ \A r \in Runners : WF_vars(StartRound(r))
    /\ \A r \in R : WF_vars(EmitBatch(r))
    /\ \A e, d \in R : \A i \in Ids :
        /\ WF_vars(\E m \in net : m.from = d /\ m.i = i /\ Diff(e, m))
        /\ WF_vars(\E m \in net : m.from = e /\ m.i = i /\ Answer(d, m))
        /\ WF_vars(\E m \in net : m.from = d /\ m.i = i /\ Receive(e, m))
        /\ WF_vars(\E x \in out[e] : x[1] = d /\ x[2] = i /\ Expire(e, x))

Spec == Init /\ [][Next]_vars
FairSpec == Spec /\ Fairness

(***************************************************************************)
(* Properties.                                                             *)
(***************************************************************************)
TypeOK ==
    /\ file \in [R -> [Ids -> Sizes]]
    /\ \A r \in R : rnd[r] \in 0..NI
    /\ losses \in 0..LossBudget /\ crashes \in 0..MaxCrashes
    /\ faults \in 0..MaxFaults

\* A file is asked of an advertiser at most once while the request, or its
\* answer, is on its way -- a file is the heaviest thing sync moves --
\* unless it was lost again meanwhile: a push can deliver it and settle the
\* request while the answer is still coming, and a copy truncated after
\* that is a new loss, rightly asked for again.
NoDuplicateRequest ==
    \A e, d \in R : \A i \in Ids :
        Cardinality({m \in net :
                       \/ m.type = "req" /\ m.from = e /\ m.to = d /\ m.i = i
                       \/ m.type = "pay" /\ m.ans /\ m.from = d /\ m.to = e
                          /\ m.i = i}) <= 1 + faults

\* Only a fault ever makes a copy smaller: no receive replaces a file with
\* a shorter one.
NoShrink ==
    [][\A r \in R, i \in Ids : file'[r][i] < file[r][i] => faults' > faults]_vars

\* Every device ends up with the largest copy any device holds.
MediaComplete == \A r \in R, i \in Ids : file[r][i] = Best(i)

\* Only inventories remain: once the copies agree, a round moves no files.
Quiet == \A m \in net : m.type = "inv"

EventuallyComplete == <>[]MediaComplete
EventuallyQuiet == <>[]Quiet
RoundTerminates == \A r \in R : [](rnd[r] # 0 => <>(rnd[r] = 0))
=============================================================================
