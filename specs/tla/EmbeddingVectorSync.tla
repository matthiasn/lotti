------------------------- MODULE EmbeddingVectorSync -------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************)
(* The register of one entry's embedding vectors, synced between devices  *)
(* (ADR 0149): `EmbeddingProcessor` writes a version, `EmbeddingVectorsSync`*)
(* sends it, and `EmbeddingSyncReceiver` merges what arrives.              *)
(*                                                                         *)
(* The entry's text has a linear history 1..MaxText (0: not arrived yet);  *)
(* a version's `src` is the text it was embedded from, so its content hash *)
(* is a function of `src`. Entries sync on their own, monotonically, and in *)
(* any order relative to the vectors. Vector messages are delivered in any *)
(* order, and any delivered one may be delivered again.                    *)
(*                                                                         *)
(* A device embeds its own edits (fairly) and, like the manual backfill,   *)
(* any text it holds whose vectors it lacks (not fairly). Receivers never  *)
(* embed synced edits. A removal — the entry deleted, or with             *)
(* ImmutableText an agent report superseded, whose text stays — is known  *)
(* only to the device that removes it and to those its entry reaches, and  *)
(* is announced by a tombstone version.                                    *)
(*                                                                         *)
(* Out of scope: the transport's own guarantees (SyncPipeline), sequence   *)
(* gaps and backfill (SyncSequence, DeepBackfill), and device trust, which *)
(* the room enforces before anything reaches the apply path.               *)
(***************************************************************************)
CONSTANTS NumDevices, MaxText, ImmutableText,
          CanonicalTieBreak, KeepTombstoneRow,
          AnnounceDeletion, TombstoneWinsTie, SkipCoveredEmbed

ASSUME /\ NumDevices \in 2..3 /\ MaxText \in 1..3
       /\ ImmutableText \in BOOLEAN
       /\ CanonicalTieBreak \in BOOLEAN /\ KeepTombstoneRow \in BOOLEAN
       /\ AnnounceDeletion \in BOOLEAN /\ TombstoneWinsTie \in BOOLEAN
       /\ SkipCoveredEmbed \in BOOLEAN

Devices == 1..NumDevices
Texts == 1..MaxText
MaxBumps == 2 * MaxText + 2
Clocks == [Devices -> 0..MaxBumps]
Zero == [e \in Devices |-> 0]
\* No version: shaped like one, so every field can be read; src 0 marks it.
None == [vc |-> Zero, src |-> 0, host |-> 1, del |-> FALSE]
Versions == [vc : Clocks, src : Texts, host : Devices, del : BOOLEAN]

VARIABLES
    latest,    \* the newest text written anywhere (0: none yet)
    author,    \* the device that wrote each text
    removed,   \* whether the entry has been removed (by anyone)
    remover,   \* the device that removed it (0: none)
    text,      \* the text each device holds
    gone,      \* whether each device knows of the removal
    seen,      \* every text each device has held
    st,        \* the version each device stores, or None
    hd,        \* the version each device holds back, or None
    msgs,      \* every version ever sent
    pending,   \* versions sent and not yet delivered, per device
    bumps      \* how many counters each device has reserved

vars == <<latest, author, removed, remover, text, gone, seen, st, hd, msgs,
          pending, bumps>>

Dominates(a, b) == \A e \in Devices : a[e] >= b[e]
Merge(a, b) == [e \in Devices |-> IF a[e] >= b[e] THEN a[e] ELSE b[e]]
WithClock(v, c) == [v EXCEPT !.vc = c]

(* Of two concurrent versions, the larger source wins, then a tombstone  *)
(* over live vectors of the same text, then the lower host: a rule over   *)
(* the two versions alone. The CanonicalTieBreak mutation prefers the one *)
(* matching the receiver's own text, which differs between receivers.    *)
Wins(d, a, b) ==
    IF CanonicalTieBreak
    THEN \/ a.src > b.src
         \/ a.src = b.src /\ TombstoneWinsTie /\ a.del /\ ~b.del
         \/ a.src = b.src /\ (a.del = b.del \/ ~TombstoneWinsTie)
            /\ a.host < b.host
    ELSE a.src = text[d] /\ b.src # text[d]

TypeOK ==
    /\ latest \in 0..MaxText /\ removed \in BOOLEAN
    /\ remover \in 0..NumDevices
    /\ author \in [Texts -> Devices \cup {0}]
    /\ text \in [Devices -> 0..MaxText] /\ gone \in [Devices -> BOOLEAN]
    /\ seen \in [Devices -> SUBSET Texts]
    /\ \A d \in Devices : st[d] \in Versions \cup {None}
    /\ \A d \in Devices : hd[d] \in Versions \cup {None}
    /\ msgs \subseteq Versions
    /\ pending \in [Devices -> SUBSET Versions]
    /\ bumps \in [Devices -> 0..MaxBumps]

Init ==
    /\ latest = 0 /\ author = [t \in Texts |-> 0] /\ removed = FALSE
    /\ remover = 0
    /\ text = [d \in Devices |-> 0] /\ gone = [d \in Devices |-> FALSE]
    /\ seen = [d \in Devices |-> {}]
    /\ st = [d \in Devices |-> None] /\ hd = [d \in Devices |-> None]
    /\ msgs = {} /\ pending = [d \in Devices |-> {}]
    /\ bumps = [d \in Devices |-> 0]

(* A device on the newest text edits it. *)
Edit(d) ==
    /\ ~removed /\ text[d] = latest /\ latest < MaxText
    /\ latest' = latest + 1
    /\ author' = [author EXCEPT ![latest + 1] = d]
    /\ text' = [text EXCEPT ![d] = latest + 1]
    /\ seen' = [seen EXCEPT ![d] = @ \cup {latest + 1}]
    /\ UNCHANGED <<removed, remover, gone, st, hd, msgs, pending, bumps>>

(* A device holding the entry removes it: deletes it, or (ImmutableText)  *)
(* its writer supersedes a report with its successor.                     *)
Remove(d) ==
    /\ ~removed /\ text[d] = latest /\ latest > 0
    /\ ~ImmutableText \/ author[latest] = d
    /\ removed' = TRUE /\ remover' = d /\ gone' = [gone EXCEPT ![d] = TRUE]
    /\ UNCHANGED <<latest, author, text, seen, st, hd, msgs, pending, bumps>>

(* The entry syncs to a device: a newer text, or a deletion. A superseded *)
(* report's own record never changes, so its removal never syncs.         *)
EntryArrives(d) ==
    \/ /\ text[d] < latest
       /\ \E t \in (text[d] + 1)..latest :
            /\ text' = [text EXCEPT ![d] = t]
            /\ seen' = [seen EXCEPT ![d] = @ \cup {t}]
       /\ UNCHANGED <<gone>>
    \/ /\ removed /\ ~ImmutableText /\ ~gone[d] /\ text[d] = latest
       /\ gone' = [gone EXCEPT ![d] = TRUE]
       /\ UNCHANGED <<text, seen>>

(* `EmbeddingProcessor`: the next version extends the stored clock with a *)
(* reserved counter of this host, is stored, and is sent.                 *)
Send(d, v) ==
    /\ st' = [st EXCEPT ![d] = v]
    /\ msgs' = msgs \cup {v}
    /\ pending' = [e \in Devices |-> IF e = d THEN pending[e] ELSE pending[e] \cup {v}]
    /\ bumps' = [bumps EXCEPT ![d] = @ + 1]

Next(d) == [IF st[d] = None THEN Zero ELSE st[d].vc EXCEPT ![d] = bumps[d] + 1]

(* Embeds the text the device holds; a skip when the stored hash matches, *)
(* and — SkipCoveredEmbed — when a tombstone made from this text or a      *)
(* later one is stored. Only its writer embeds an agent report.            *)
Embed(d) ==
    /\ ~gone[d] /\ text[d] > 0
    /\ ~ImmutableText \/ author[text[d]] = d
    /\ st[d] = None \/ st[d].del \/ st[d].src # text[d]
    /\ ~(SkipCoveredEmbed /\ st[d] # None /\ st[d].del /\ st[d].src >= text[d])
    /\ Send(d, [vc |-> Next(d), src |-> text[d], host |-> d, del |-> FALSE])
    /\ UNCHANGED <<latest, author, removed, remover, text, gone, seen, hd>>

EmbedOwn(d) == text[d] > 0 /\ author[text[d]] = d /\ Embed(d)

(* A removal is a tombstone version, made from the text removed, and     *)
(* sent only by the device that removed the entry: a receiver never       *)
(* processes a synced deletion. It goes out when there is something to    *)
(* remove — stored vectors that are no tombstone — and, for a deleted     *)
(* entry with AnnounceDeletion, even when this device holds none.         *)
Tombstone(d) ==
    /\ d = remover
    /\ st[d] = None \/ ~st[d].del
    /\ st[d] # None \/ (AnnounceDeletion /\ ~ImmutableText)
    /\ Send(d, [vc |-> Next(d), src |-> text[d], host |-> d, del |-> TRUE])
    /\ UNCHANGED <<latest, author, removed, remover, text, gone, seen, hd>>

(* `EmbeddingSyncReceiver._merge` of version m on device d, with what it  *)
(* holds back first set to h (a release takes the held version out).      *)
Apply(d, m, h) ==
    LET s == st[d]
        vsStored ==
          IF s = None THEN [go |-> TRUE, cand |-> m, st |-> s]
          ELSE IF Dominates(s.vc, m.vc) THEN [go |-> FALSE, cand |-> m, st |-> s]
          ELSE IF Dominates(m.vc, s.vc) THEN [go |-> TRUE, cand |-> m, st |-> s]
          ELSE IF Wins(d, s, m)
               THEN [go |-> FALSE, cand |-> m, st |-> WithClock(s, Merge(s.vc, m.vc))]
               ELSE [go |-> TRUE, cand |-> WithClock(m, Merge(s.vc, m.vc)), st |-> s]
        c1 == vsStored.cand
        vsHeld ==
          IF ~vsStored.go \/ h = None THEN [go |-> vsStored.go, cand |-> c1, hd |-> h]
          ELSE IF Dominates(h.vc, c1.vc) THEN [go |-> FALSE, cand |-> c1, hd |-> h]
          ELSE IF Dominates(c1.vc, h.vc) THEN [go |-> TRUE, cand |-> c1, hd |-> h]
          ELSE IF Wins(d, h, c1)
               THEN [go |-> FALSE, cand |-> c1, hd |-> WithClock(h, Merge(h.vc, c1.vc))]
               ELSE [go |-> TRUE, cand |-> WithClock(c1, Merge(h.vc, c1.vc)), hd |-> h]
        c == vsHeld.cand
        \* A stored winner that took the merged clock drops a held version
        \* the merged clock covers.
        keptHd == IF ~vsStored.go /\ h # None /\ vsStored.st # None
                     /\ Dominates(vsStored.st.vc, h.vc)
                  THEN None ELSE vsHeld.hd
    IN IF ~vsHeld.go
       THEN /\ st' = [st EXCEPT ![d] = vsStored.st]
            /\ hd' = [hd EXCEPT ![d] = keptHd]
       ELSE IF c.del
       THEN /\ st' = [st EXCEPT ![d] = IF KeepTombstoneRow \/ s # None THEN c ELSE None]
            /\ hd' = [hd EXCEPT ![d] = None]
       \* A deleted entry reads as missing: what arrives for it is held.
       ELSE IF text[d] = c.src /\ ~(gone[d] /\ ~ImmutableText)
       THEN /\ st' = [st EXCEPT ![d] = c]
            /\ hd' = [hd EXCEPT ![d] = None]
       \* The entry moved past the text: never released, so discarded.
       ELSE IF text[d] > c.src
       THEN /\ st' = [st EXCEPT ![d] = s]
            /\ hd' = [hd EXCEPT ![d] = None]
       ELSE /\ st' = [st EXCEPT ![d] = s]
            /\ hd' = [hd EXCEPT ![d] = c]

Deliver(d) ==
    /\ \E m \in pending[d] :
         /\ Apply(d, m, hd[d])
         /\ pending' = [pending EXCEPT ![d] = @ \ {m}]
    /\ UNCHANGED <<latest, author, removed, remover, text, gone, seen, msgs, bumps>>

(* Lease redelivery: a version already delivered arrives again. *)
Redeliver(d) ==
    /\ \E m \in msgs \ pending[d] : Apply(d, m, hd[d])
    /\ UNCHANGED <<latest, author, removed, remover, text, gone, seen, msgs,
                   pending, bumps>>

(* A hook — the entry, the report or a label applied — or the drain sweep *)
(* re-runs the merge for what is held back.                               *)
Release(d) ==
    /\ hd[d] # None
    /\ Apply(d, hd[d], None)
    /\ hd'[d] # hd[d] \/ st'[d] # st[d]
    /\ UNCHANGED <<latest, author, removed, remover, text, gone, seen, msgs,
                   pending, bumps>>

ArriveStep(d) ==
    /\ EntryArrives(d)
    /\ UNCHANGED <<latest, author, removed, remover, st, hd, msgs, pending, bumps>>

Step ==
    \E d \in Devices :
        \/ Edit(d) \/ Remove(d) \/ ArriveStep(d)
        \/ Embed(d) \/ Tombstone(d)
        \/ Deliver(d) \/ Redeliver(d) \/ Release(d)

Spec ==
    /\ Init /\ [][Step]_vars
    /\ \A d \in Devices :
         /\ WF_vars(ArriveStep(d)) /\ WF_vars(EmbedOwn(d))
         /\ WF_vars(Tombstone(d)) /\ WF_vars(Deliver(d))
         /\ WF_vars(Release(d))

---------------------------------------------------------------------------
(* Safety *)

(* A device stores vectors only of a text it has held: the hash check.    *)
NoForeignVectors ==
    \A d \in Devices : st[d] # None /\ ~st[d].del => st[d].src \in seen[d]

(* No clock holds a counter its host did not reserve: receivers merge and *)
(* never bump.                                                            *)
ReceiverNeverBumps ==
    \A d, e \in Devices :
        /\ st[d] # None => st[d].vc[e] <= bumps[e]
        /\ hd[d] # None => hd[d].vc[e] <= bumps[e]

(* A device's stored version only moves forward in its clock.             *)
StoredClockMonotone ==
    [][\A d \in Devices :
         st[d] # None /\ st'[d] # None => Dominates(st'[d].vc, st[d].vc)]_vars

---------------------------------------------------------------------------
(* Liveness *)

(* Nothing is held back for good once its dependencies have arrived.      *)
HeldReleased == \A d \in Devices : hd[d] # None ~> hd[d] = None

(* Once quiet, every device stores the same version: the newest text's,   *)
(* by the same winner, or the tombstone of a removed entry.               *)
Converged ==
    /\ \A d \in Devices : text[d] = latest
    /\ IF latest = 0 THEN TRUE
       ELSE IF removed
       THEN \A d \in Devices : st[d] = None \/ st[d].del
       ELSE \A d, e \in Devices :
              /\ st[d] # None /\ st[e] # None
              /\ st[d].src = latest /\ ~st[d].del
              /\ st[d].host = st[e].host

EventuallyConverged == <>[]Converged
=============================================================================
