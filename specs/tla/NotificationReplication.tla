---------------------- MODULE NotificationReplication ----------------------
(***************************************************************************)
(* One notification: two equal-updatedAt content snapshots and two state  *)
(* patches. Content differs only after meta in canonical JSON, so the     *)
(* legacy originatingHostId key can outrank it. State patches change the  *)
(* owner without changing updatedAt. Lifecycle marks use earliest nonnull.*)
(*                                                                         *)
(* Send/Deliver: durable outbox -> immutable envelope -> inbound queue.   *)
(* Apply: NotificationsDb transactional upsertNotification / mergeState.  *)
(* Ack: notification receive handler records receipt only after apply.   *)
(* Request/Repair: visible gaps request the CURRENT full or state row,   *)
(* matching the requested payload type in BackfillResponseHandler.      *)
(* The fixed source retains the joined row throughout this bounded run. *)
(* Crash: volatile post-apply work is lost; the durable inbox replays.    *)
(*                                                                         *)
(* No database absence, purges, corrupt attachments, terminal retry cap,  *)
(* OS alarms, or source-side crashes. The source starts with four durable *)
(* enqueued events. Liveness requires an observed final counter, fair    *)
(* draining and repair, and the retained source row. An unobserved lost   *)
(* tail is deliberately not promised to heal. Outbox                    *)
(* cover staging/claims; InboundQueue covers the detailed retry machine. *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets
CONSTANTS Peers, MaxLosses, MaxCrashes, LegacyContentTie,
          RequireBase, AckAfterApply, AckRepairIndividually
Events == 1..4
Requests == Peers \X Events
RepairCarries(e) == IF e <= 2 THEN Events ELSE {3, 4}
Fields == {"seen", "acted", "deleted"}
EmptyMarks == [f \in Fields |-> 0]
Marks(e) == CASE e = 3 -> [f \in Fields |-> IF f = "seen" THEN 2 ELSE 0]
             [] e = 4 -> [f \in Fields |-> 1]
             [] OTHER -> EmptyMarks
MinMark(a, b) == IF a = 0 THEN b ELSE IF b = 0 THEN a
                ELSE IF a < b THEN a ELSE b
JoinMarks(a, b) == [f \in Fields |-> MinMark(a[f], b[f])]
EmptyRow == [content |-> 0, owner |-> 0, marks |-> EmptyMarks]
Snapshot == [content |-> 2, owner |-> 3, marks |-> Marks(4)]
Full(e) == [content |-> e, owner |-> e, marks |-> EmptyMarks]
Wins(a, b) == IF LegacyContentTie /\ a.owner # b.owner
             THEN a.owner > b.owner ELSE a.content >= b.content
Merge(a, b) == LET winner == IF Wins(a, b) THEN a ELSE b
              IN [winner EXCEPT !.marks = JoinMarks(a.marks, b.marks)]
ApplyRow(row, e) == IF e <= 2 THEN Merge(row, Full(e))
                   ELSE [row EXCEPT !.owner = 3,
                         !.marks = JoinMarks(@, Marks(e))]
Projection(row) == <<row.content, row.marks>>

\* Proof history: counters seen in envelopes or in their own typed repair
\* response. A snapshot carrying data for other counters is not their receipt.
\* This is observer history, not a new database field or a decision input.
\* attempted includes lost envelopes; receivedCounters does not.
VARIABLES outbox, wire, attempted, inbox, rows, applied, receipts, acked,
          head, requested, repairing, losses, crashes, receivedCounters
vars == <<outbox, wire, attempted, inbox, rows, applied, receipts, acked,
          head, requested, repairing, losses, crashes, receivedCounters>>
Init == /\ outbox = Events /\ wire = {}
        /\ attempted = [p \in Peers |-> {}]
        /\ receivedCounters = [p \in Peers |-> {}]
        /\ inbox = [p \in Peers |-> {}]
        /\ rows = [p \in Peers |-> EmptyRow]
        /\ applied = [p \in Peers |-> {}]
        /\ receipts = [p \in Peers |-> {}]
        /\ acked = [p \in Peers |-> {}]
        /\ head = [p \in Peers |-> 0]
        /\ requested = {} /\ repairing = {}
        /\ losses = 0 /\ crashes = 0
Send(e) == /\ e \in outbox
           /\ outbox' = outbox \ {e} /\ wire' = wire \cup {e}
           /\ UNCHANGED <<attempted, inbox, rows, applied, receipts, acked,
                           head, requested, repairing, losses, crashes, receivedCounters>>
Deliver(p, e) ==
    /\ e \in wire \ attempted[p]
    /\ attempted' = [attempted EXCEPT ![p] = @ \cup {e}]
    /\ receivedCounters' = [receivedCounters EXCEPT ![p] = @ \cup {e}]
    /\ inbox' = [inbox EXCEPT ![p] = @ \cup {e}]
    /\ head' = [head EXCEPT ![p] = IF e > @ THEN e ELSE @]
    /\ UNCHANGED <<outbox, wire, rows, applied, receipts, acked, requested,
                    repairing, losses, crashes>>
Lose(p, e) ==
    /\ e \in wire \ attempted[p] /\ losses < MaxLosses
    /\ attempted' = [attempted EXCEPT ![p] = @ \cup {e}]
    /\ losses' = losses + 1
    /\ UNCHANGED <<outbox, wire, inbox, rows, applied, receipts, acked,
                    head, requested, repairing, crashes, receivedCounters>>
Apply(p, e) ==
    /\ e \in inbox[p] \ receipts[p]
    /\ ~RequireBase \/ e <= 2 \/ rows[p].content # 0
    /\ rows' = [rows EXCEPT ![p] = ApplyRow(@, e)]
    /\ applied' = [applied EXCEPT ![p] = @ \cup {e}]
    /\ receipts' = [receipts EXCEPT ![p] = @ \cup {e}]
    /\ UNCHANGED <<outbox, wire, attempted, inbox, acked, head, requested,
                    repairing, losses, crashes, receivedCounters>>
Ack(p, e) ==
    /\ e \in inbox[p]
    /\ ~AckAfterApply \/ e \in receipts[p]
    /\ acked' = [acked EXCEPT ![p] = @ \cup {e}]
    /\ inbox' = [inbox EXCEPT ![p] = @ \ {e}]
    /\ UNCHANGED <<outbox, wire, attempted, rows, applied, receipts, head,
                    requested, repairing, losses, crashes, receivedCounters>>
Request(p, e) ==
    /\ <<p, e>> \notin requested /\ <<p, e>> \notin repairing
    /\ e \in (1..head[p]) \ (acked[p] \cup inbox[p])
    /\ requested' = requested \cup {<<p, e>>}
    /\ UNCHANGED <<outbox, wire, attempted, inbox, rows, applied, receipts,
                    acked, head, repairing, losses, crashes, receivedCounters>>
Repair(p, e) ==
    /\ <<p, e>> \in requested /\ <<p, e>> \notin repairing
    /\ e <= 2 \/ rows[p].content # 0
    /\ rows' = [rows EXCEPT ![p] = IF e <= 2 THEN Merge(@, Snapshot)
                                  ELSE ApplyRow(@, 4)]
    /\ applied' = [applied EXCEPT ![p] = @ \cup RepairCarries(e)]
    /\ receivedCounters' = [receivedCounters EXCEPT ![p] = @ \cup {e}]
    /\ repairing' = repairing \cup {<<p, e>>}
    /\ UNCHANGED <<outbox, wire, attempted, inbox, receipts, acked, head,
                    requested, losses, crashes>>
AckRepair(p, e) ==
    /\ <<p, e>> \in repairing
    /\ acked' = [acked EXCEPT ![p] = @ \cup
                  (IF AckRepairIndividually THEN {e} ELSE RepairCarries(e))]
    /\ requested' = requested \ {<<p, e>>}
    /\ repairing' = repairing \ {<<p, e>>}
    /\ UNCHANGED <<outbox, wire, attempted, inbox, rows, applied, receipts,
                    head, losses, crashes, receivedCounters>>
Crash ==
    /\ crashes < MaxCrashes
    /\ receipts' = [p \in Peers |-> {}] /\ repairing' = {}
    /\ crashes' = crashes + 1
    /\ UNCHANGED <<outbox, wire, attempted, inbox, rows, applied, acked,
                    head, requested, losses, receivedCounters>>
Next == (\E e \in Events : Send(e)) \/ Crash
        \/ (\E p \in Peers, e \in Events : Deliver(p, e) \/ Lose(p, e)
                 \/ Apply(p, e) \/ Ack(p, e))
        \/ (\E p \in Peers, e \in Events :
                 Request(p, e) \/ Repair(p, e) \/ AckRepair(p, e))
Spec == Init /\ [][Next]_vars
        /\ (\A e \in Events : WF_vars(Send(e)))
        /\ (\A p \in Peers, e \in Events :
              WF_vars(Deliver(p, e)) /\ WF_vars(Apply(p, e)) /\ WF_vars(Ack(p, e)))
        /\ (\A p \in Peers, e \in Events :
              WF_vars(Request(p, e)) /\ WF_vars(Repair(p, e))
              /\ WF_vars(AckRepair(p, e)))
TypeOK == /\ outbox \subseteq Events /\ wire \subseteq Events
          /\ \A p \in Peers :
               /\ attempted[p] \subseteq Events /\ inbox[p] \subseteq Events
               /\ applied[p] \subseteq Events /\ receipts[p] \subseteq Events
               /\ acked[p] \subseteq Events /\ head[p] \in 0..4
               /\ receivedCounters[p] \subseteq Events
               /\ rows[p].content \in 0..2 /\ rows[p].owner \in 0..3
               /\ rows[p].marks \in [Fields -> 0..2]
          /\ requested \subseteq Requests /\ repairing \subseteq Requests
          /\ losses \in 0..MaxLosses /\ crashes \in 0..MaxCrashes
NoFalseReceipt == \A p \in Peers :
    acked[p] \subseteq (applied[p] \cap receivedCounters[p])
NoStateWithoutBase == \A p \in Peers : rows[p].marks # EmptyMarks =>
                                                   rows[p].content # 0
LifecyclePreserved == \A p \in Peers : \A e \in applied[p] :
    \A f \in Fields : Marks(e)[f] # 0 =>
        rows[p].marks[f] # 0 /\ rows[p].marks[f] <= Marks(e)[f]
ContentConverged == \A p \in Peers : {1, 2} \subseteq applied[p] =>
                                                   rows[p].content = 2
AcknowledgedConverges == \A p \in Peers : acked[p] = Events =>
                                     Projection(rows[p]) = Projection(Snapshot)
VisibleGapHeals == \A p \in Peers : head[p] = 4 ~> acked[p] = Events
=============================================================================
