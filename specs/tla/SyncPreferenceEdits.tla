----------------------- MODULE SyncPreferenceEdits -----------------------
(***************************************************************************)
(* Local theme/name commits, debounce coalescing, publication and remote    *)
(* register application. Each peer makes two edits while its wall clock    *)
(* stays at 1. A local stamp must advance beyond the persisted register.   *)
(* A debounce retains the committed snapshot even if receive changes the  *)
(* register before publication. Payload integers stand for canonical      *)
(* payload tuples, not a wire field or a sender sequence number.           *)
(*                                                                       *)
(* Group commits are atomic here: SyncSettings and SQLite regressions     *)
(* separately open their failure boundary. No crash, failed publication,  *)
(* cancelled debounce, missing delivery or legacy writer is modeled.     *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets
CONSTANTS Peers, MaxEdits, MonotoneLocalStamps, PublishCommittedSnapshot
ASSUME Peers = 1..Cardinality(Peers) /\ MaxEdits \in Nat \ {0}
MaxStamp == Cardinality(Peers) * MaxEdits
Payloads == 1..MaxStamp
Versions == (1..MaxStamp) \X Payloads
Empty == <<0, 0>>
Greater(a, b) == a[1] > b[1] \/ (a[1] = b[1] /\ a[2] > b[2])
AtLeast(a, b) == a = b \/ Greater(a, b)
VARIABLES stored, pending, edits, committed, room, delivered, localAdvanced
vars == <<stored, pending, edits, committed, room, delivered, localAdvanced>>
Init == /\ stored = [p \in Peers |-> Empty]
        /\ pending = [p \in Peers |-> Empty]
        /\ edits = [p \in Peers |-> 0]
        /\ committed = {}
        /\ room = {}
        /\ delivered = [p \in Peers |-> {}]
        /\ localAdvanced = TRUE
LocalEdit(p) ==
    /\ edits[p] < MaxEdits
    /\ LET stamp == IF MonotoneLocalStamps THEN stored[p][1] + 1 ELSE 1
           payload == (p - 1) * MaxEdits + edits[p] + 1
           version == <<stamp, payload>>
       IN /\ stored' = [stored EXCEPT ![p] = version]
          /\ pending' = [pending EXCEPT ![p] = version]
          /\ committed' = committed \cup {version}
          /\ localAdvanced' = (localAdvanced /\ stamp > stored[p][1])
    /\ edits' = [edits EXCEPT ![p] = @ + 1]
    /\ UNCHANGED <<room, delivered>>
Publish(p) ==
    /\ pending[p] # Empty
    /\ LET version == IF PublishCommittedSnapshot THEN pending[p]
                      ELSE <<pending[p][1], stored[p][2]>>
       IN room' = room \cup {version}
    /\ pending' = [pending EXCEPT ![p] = Empty]
    /\ UNCHANGED <<stored, edits, committed, delivered, localAdvanced>>
Receive(p, v) ==
    /\ v \in room \ delivered[p]
    /\ stored' = [stored EXCEPT ![p] = IF Greater(v, @) THEN v ELSE @]
    /\ delivered' = [delivered EXCEPT ![p] = @ \cup {v}]
    /\ UNCHANGED <<pending, edits, committed, room, localAdvanced>>
Next == (\E p \in Peers : LocalEdit(p) \/ Publish(p))
        \/ (\E p \in Peers, v \in Versions : Receive(p, v))
Spec == Init /\ [][Next]_vars
        /\ (\A p \in Peers : WF_vars(LocalEdit(p)) /\ WF_vars(Publish(p)))
        /\ (\A p \in Peers, v \in Versions : WF_vars(Receive(p, v)))
TypeOK == /\ stored \in [Peers -> Versions \cup {Empty}]
          /\ pending \in [Peers -> Versions \cup {Empty}]
          /\ edits \in [Peers -> 0..MaxEdits]
          /\ committed \subseteq Versions
          /\ room \subseteq Versions
          /\ delivered \in [Peers -> SUBSET Versions]
          /\ localAdvanced \in BOOLEAN
LocalVersionsAdvance == localAdvanced
OnlyCommittedSnapshots == room \subseteq committed
Settled == \A p \in Peers :
    edits[p] = MaxEdits /\ pending[p] = Empty /\ room \subseteq delivered[p]
SettledPeersAgree == Settled => \A p, q \in Peers : stored[p] = stored[q]
SettledRetainsEveryEdit == Settled =>
    \A p \in Peers, v \in committed : AtLeast(stored[p], v)
EventuallySettled == <> Settled
EveryEditEventuallyCovered == \A v \in Versions :
    v \in committed ~> (\A p \in Peers : AtLeast(stored[p], v))
=============================================================================
