------------------------- MODULE GitHubAccountSync -------------------------
(***************************************************************************)
(* The user's GitHub token, syncing between their devices (a design model).*)
(*                                                                         *)
(* Each device holds one record in its keychain: a token or none (a        *)
(* disconnection), the stamp of the change, and whether this device has    *)
(* checked the token with GitHub itself. A change made on a device — a     *)
(* token entered and accepted by GitHub, or a disconnection — is stamped   *)
(* with that device's clock and sent to the others; a received record      *)
(* replaces the held one if it is newer: a later stamp, or the same stamp  *)
(* and the greater content. Device clocks disagree. Sync delivers in any   *)
(* order, and a device may send what it holds again (the settings page's   *)
(* "send to my other devices"). GitHub may revoke a token at any time.     *)
(*                                                                         *)
(* SyncSettings models how one received settings value is applied; this    *)
(* model adds what that one leaves out: changes made on the devices        *)
(* themselves, racing the ones that arrive, and a value a device must      *)
(* check before it shows it.                                               *)
(*                                                                         *)
(* Tokens are 1..TokenCount, and 0 is no token, so content compares as a   *)
(* number: GitHubAccountRecord.isNewerThan compares the token and login as *)
(* a string the same way.                                                  *)
(*                                                                         *)
(* What is modelled, and where it lives in the Dart code:                  *)
(*                                                                         *)
(*   Connect     GitHubAccountController.connect → GitHubTokenStorage.save *)
(*               → GitHubAccountSync.publish                               *)
(*   Disconnect  GitHubAccountController.disconnect → clear → publish      *)
(*   Resend      GitHubAccountController.sendToOtherDevices                *)
(*   Receive     SyncEventProcessor (SyncGitHubAccount) →                  *)
(*               GitHubTokenStorage.applyIfNewer                           *)
(*   Verify      GitHubAccountController.build: GET /user, then            *)
(*               markVerified, or the rejection shown                      *)
(*   Revoke      the user revoking the token on github.com                 *)
(*   Tick        a device's clock moving on                                *)
(*                                                                         *)
(* Every switch is TRUE in the checked-in configuration; README.md lists   *)
(* the counterexample each has when FALSE.                                 *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets

CONSTANTS
    Devices,
    TokenCount,
    MaxClock,           \* bound on each device's clock
    MaxChanges,         \* bound on connects and disconnects, all devices
    \* design switches
    BumpStamp,          \* a change is stamped past the version it was made over
    DeterministicTies,  \* an equal stamp is decided by content
    VerifyReceived      \* a received token is checked here before it shows

Tokens == 1..TokenCount
None == 0
Record == [tok : 0..TokenCount, stamp : Nat, verified : BOOLEAN]

VARIABLES
    held,      \* per device: its keychain record
    clock,     \* per device: its clock, in stamp units
    msgs,      \* records in flight: [to, tok, stamp]
    valid,     \* the tokens GitHub accepts now
    checked,   \* ghost: per device, the <<token, stamp>> versions it checked with GitHub
    changes    \* bound counter

vars == <<held, clock, msgs, valid, checked, changes>>

Empty == [tok |-> None, stamp |-> 0, verified |-> FALSE]

\* The version a device's change replaces is never newer than the change.
NextStamp(d) ==
    IF BumpStamp /\ clock[d] <= held[d].stamp
    THEN held[d].stamp + 1
    ELSE clock[d]

\* Whether version <<t, s>> replaces <<u, r>>.
Newer(t, s, u, r) ==
    \/ s > r
    \/ (DeterministicTies /\ s = r /\ t > u)

Send(d, t, s) == msgs \cup {[to |-> o, tok |-> t, stamp |-> s] : o \in Devices \ {d}}

Init ==
    /\ held = [d \in Devices |-> Empty]
    /\ clock = [d \in Devices |-> 1]
    /\ msgs = {}
    /\ valid = Tokens
    /\ checked = [d \in Devices |-> {}]
    /\ changes = 0

Tick(d) ==
    /\ clock[d] < MaxClock
    /\ clock' = [clock EXCEPT ![d] = @ + 1]
    /\ UNCHANGED <<held, msgs, valid, checked, changes>>

\* The user enters token t here, and GitHub accepts it.
Connect(d, t) ==
    LET s == NextStamp(d) IN
    /\ changes < MaxChanges
    /\ t \in valid
    /\ held' = [held EXCEPT ![d] = [tok |-> t, stamp |-> s, verified |-> TRUE]]
    /\ checked' = [checked EXCEPT ![d] = @ \cup {<<t, s>>}]
    /\ msgs' = Send(d, t, s)
    /\ changes' = changes + 1
    /\ UNCHANGED <<clock, valid>>

Disconnect(d) ==
    LET s == NextStamp(d) IN
    /\ changes < MaxChanges
    /\ held[d].tok # None
    /\ held' = [held EXCEPT ![d] = [tok |-> None, stamp |-> s, verified |-> FALSE]]
    /\ msgs' = Send(d, None, s)
    /\ changes' = changes + 1
    /\ UNCHANGED <<clock, valid, checked>>

\* Sends what is held again, with its own stamp.
Resend(d) ==
    /\ held[d].tok # None
    /\ msgs' = Send(d, held[d].tok, held[d].stamp)
    /\ UNCHANGED <<held, clock, valid, checked, changes>>

Receive(m) ==
    LET d == m.to IN
    /\ m \in msgs
    /\ msgs' = msgs \ {m}
    /\ held' = IF Newer(m.tok, m.stamp, held[d].tok, held[d].stamp)
               THEN [held EXCEPT ![d] =
                       [tok |-> m.tok, stamp |-> m.stamp,
                        verified |-> ~VerifyReceived /\ m.tok # None]]
               ELSE held
    /\ UNCHANGED <<clock, valid, checked, changes>>

\* This device checks the token it received: GitHub accepts it, or the
\* rejection is shown and the token is not.
Verify(d) ==
    /\ held[d].tok # None
    /\ ~held[d].verified
    /\ held[d].tok \in valid
    /\ held' = [held EXCEPT ![d].verified = TRUE]
    /\ checked' = [checked EXCEPT ![d] = @ \cup {<<held[d].tok, held[d].stamp>>}]
    /\ UNCHANGED <<clock, msgs, valid, changes>>

Revoke(t) ==
    /\ t \in valid
    /\ valid' = valid \ {t}
    /\ UNCHANGED <<held, clock, msgs, checked, changes>>

Next ==
    \/ \E d \in Devices : Tick(d) \/ Disconnect(d) \/ Resend(d) \/ Verify(d)
    \/ \E d \in Devices, t \in Tokens : Connect(d, t)
    \/ \E m \in msgs : Receive(m)
    \/ \E t \in Tokens : Revoke(t)

Spec == Init /\ [][Next]_vars

-----------------------------------------------------------------------------

TypeOK ==
    /\ held \in [Devices -> [tok : 0..TokenCount,
                             stamp : 0..(MaxClock + MaxChanges),
                             verified : BOOLEAN]]
    /\ clock \in [Devices -> 1..MaxClock]

\* A device shows a token as connected only once it checked that version
\* with GitHub itself — entered here, or received and verified here.
ShownWasChecked ==
    \A d \in Devices :
        held[d].verified => <<held[d].tok, held[d].stamp>> \in checked[d]

\* With nothing in flight, every device holds the same token, or none, at
\* the same stamp: a disconnection reaches every device as a connection does.
Converged ==
    msgs = {} =>
        \A a, b \in Devices :
            /\ held[a].tok = held[b].tok
            /\ held[a].stamp = held[b].stamp

\* A change made on a device outranks the version it was made over, however
\* far that device's clock is behind the one that made the held version: the
\* user's last action there is what that device keeps, and sends.
LocalChangeOutranks ==
    [][changes' = changes + 1 =>
         \A d \in Devices : held'[d] # held[d] => held'[d].stamp > held[d].stamp]_vars
=============================================================================
