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
(*               → GitHubAccountSync.flushOwed; the outbox may refuse the  *)
(*               row, and then the change stays owed                       *)
(*   Disconnect  GitHubAccountController.disconnect → clear → flushOwed    *)
(*   Flush       GitHubAccountSync.flushOwed: at startup, and after each   *)
(*               change; sends what is owed, then clears the mark          *)
(*   Resend      GitHubAccountController.sendToOtherDevices                *)
(*   Receive     SyncEventProcessor (SyncGitHubAccount) →                  *)
(*               GitHubTokenStorage.applyIfNewer; without AtomicApply its  *)
(*               read and its write are two steps (Take, then Apply)       *)
(*   VerifyStart GitHubAccountController.build: GET /user for the held    *)
(*               version                                                   *)
(*   VerifyEnd   ...then markVerified for that version, or the rejection   *)
(*               shown                                                     *)
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
    VerifyReceived,     \* a received token is checked here before it shows
    VerifyMatchesVersion, \* a check marks only the version it checked
    AtomicApply,        \* a received version is compared and written in one step
    RetryOwed           \* a change the outbox refused is sent again later

Tokens == 1..TokenCount
None == 0
NoTok == TokenCount + 1  \* nothing pending
Idle == [tok |-> NoTok, stamp |-> 0, baseTok |-> NoTok, baseStamp |-> 0, ok |-> FALSE]

VARIABLES
    held,      \* per device: its keychain record
    clock,     \* per device: its clock, in stamp units
    msgs,      \* records in flight: [to, tok, stamp]
    owed,      \* per device: a change made here that is not sent yet
    applying,  \* per device: a received version read but not yet written
    checking,  \* per device: a GitHub check under way, and its answer
    valid,     \* the tokens GitHub accepts now
    checked,   \* ghost: per device, the <<token, stamp>> versions it checked with GitHub
    changes    \* bound counter

vars == <<held, clock, msgs, owed, applying, checking, valid, checked, changes>>

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

\* A change made here goes to the others — or, when the outbox refuses the
\* row, stays owed (RetryOwed) or is lost.
Publish(d, t, s, sent) ==
    IF sent
    THEN /\ msgs' = Send(d, t, s)
         /\ owed' = [owed EXCEPT ![d] = FALSE]
    ELSE /\ msgs' = msgs
         /\ owed' = [owed EXCEPT ![d] = RetryOwed]

Init ==
    /\ held = [d \in Devices |-> Empty]
    /\ clock = [d \in Devices |-> 1]
    /\ msgs = {}
    /\ owed = [d \in Devices |-> FALSE]
    /\ applying = [d \in Devices |-> Idle]
    /\ checking = [d \in Devices |-> Idle]
    /\ valid = Tokens
    /\ checked = [d \in Devices |-> {}]
    /\ changes = 0

Tick(d) ==
    /\ clock[d] < MaxClock
    /\ clock' = [clock EXCEPT ![d] = @ + 1]
    /\ UNCHANGED <<held, msgs, owed, applying, checking, valid, checked, changes>>

\* The user enters token t here, and GitHub accepts it.
Connect(d, t, sent) ==
    LET s == NextStamp(d) IN
    /\ changes < MaxChanges
    /\ t \in valid
    /\ held' = [held EXCEPT ![d] = [tok |-> t, stamp |-> s, verified |-> TRUE]]
    /\ checked' = [checked EXCEPT ![d] = @ \cup {<<t, s>>}]
    /\ Publish(d, t, s, sent)
    /\ changes' = changes + 1
    /\ UNCHANGED <<clock, applying, checking, valid>>

Disconnect(d, sent) ==
    LET s == NextStamp(d) IN
    /\ changes < MaxChanges
    /\ held[d].tok # None
    /\ held' = [held EXCEPT ![d] = [tok |-> None, stamp |-> s, verified |-> FALSE]]
    /\ Publish(d, None, s, sent)
    /\ changes' = changes + 1
    /\ UNCHANGED <<clock, applying, checking, valid, checked>>

\* Sends what is owed: the record held now, with its own stamp.
Flush(d) ==
    /\ owed[d]
    /\ msgs' = Send(d, held[d].tok, held[d].stamp)
    /\ owed' = [owed EXCEPT ![d] = FALSE]
    /\ UNCHANGED <<held, clock, applying, checking, valid, checked, changes>>

\* Sends what is held again, with its own stamp.
Resend(d) ==
    /\ held[d].tok # None
    /\ msgs' = Send(d, held[d].tok, held[d].stamp)
    /\ owed' = [owed EXCEPT ![d] = FALSE]
    /\ UNCHANGED <<held, clock, applying, checking, valid, checked, changes>>

Received(d, t, s) ==
    [tok |-> t, stamp |-> s, verified |-> ~VerifyReceived /\ t # None]

\* With AtomicApply, one step: compared with what is held now, and written.
Receive(m) ==
    LET d == m.to IN
    /\ m \in msgs
    /\ applying[d] = Idle
    /\ msgs' = msgs \ {m}
    /\ IF AtomicApply
       THEN /\ held' = IF Newer(m.tok, m.stamp, held[d].tok, held[d].stamp)
                        THEN [held EXCEPT ![d] = Received(d, m.tok, m.stamp)]
                        ELSE held
            /\ UNCHANGED applying
       ELSE /\ applying' = [applying EXCEPT ![d] =
                 [tok |-> m.tok, stamp |-> m.stamp, baseTok |-> held[d].tok,
                  baseStamp |-> held[d].stamp, ok |-> FALSE]]
            /\ UNCHANGED held
    /\ UNCHANGED <<clock, owed, checking, valid, checked, changes>>

\* Without AtomicApply: the write, decided on the version read before.
Apply(d) ==
    LET a == applying[d] IN
    /\ a # Idle
    /\ held' = IF Newer(a.tok, a.stamp, a.baseTok, a.baseStamp)
                THEN [held EXCEPT ![d] = Received(d, a.tok, a.stamp)]
                ELSE held
    /\ applying' = [applying EXCEPT ![d] = Idle]
    /\ UNCHANGED <<clock, msgs, owed, checking, valid, checked, changes>>

\* This device asks GitHub about the version it holds; the answer comes back
\* in VerifyEnd, by which time the held version may have changed.
VerifyStart(d) ==
    /\ held[d].tok # None
    /\ ~held[d].verified
    /\ checking[d] = Idle
    /\ checking' = [checking EXCEPT ![d] =
         [tok |-> held[d].tok, stamp |-> held[d].stamp, baseTok |-> NoTok,
          baseStamp |-> 0, ok |-> held[d].tok \in valid]]
    /\ UNCHANGED <<held, clock, msgs, owed, applying, valid, checked, changes>>

VerifyEnd(d) ==
    LET c == checking[d]
        same == held[d].tok = c.tok /\ held[d].stamp = c.stamp
    IN
    /\ c # Idle
    /\ IF c.ok /\ held[d].tok # None /\ (same \/ ~VerifyMatchesVersion)
       THEN /\ held' = [held EXCEPT ![d].verified = TRUE]
            /\ checked' = [checked EXCEPT ![d] = @ \cup {<<c.tok, c.stamp>>}]
       ELSE UNCHANGED <<held, checked>>
    /\ checking' = [checking EXCEPT ![d] = Idle]
    /\ UNCHANGED <<clock, msgs, owed, applying, valid, changes>>

Revoke(t) ==
    /\ t \in valid
    /\ valid' = valid \ {t}
    /\ UNCHANGED <<held, clock, msgs, owed, applying, checking, checked, changes>>

Next ==
    \/ \E d \in Devices : \/ Tick(d) \/ Flush(d) \/ Resend(d) \/ Apply(d)
                         \/ VerifyStart(d) \/ VerifyEnd(d)
    \/ \E d \in Devices, sent \in BOOLEAN : Disconnect(d, sent)
    \/ \E d \in Devices, t \in Tokens, sent \in BOOLEAN : Connect(d, t, sent)
    \/ \E m \in msgs : Receive(m)
    \/ \E t \in Tokens : Revoke(t)

Spec == Init /\ [][Next]_vars

-----------------------------------------------------------------------------

TypeOK ==
    /\ held \in [Devices -> [tok : 0..TokenCount,
                             stamp : 0..(MaxClock + MaxChanges),
                             verified : BOOLEAN]]
    /\ clock \in [Devices -> 1..MaxClock]
    /\ owed \in [Devices -> BOOLEAN]

\* A device shows a token as connected only once it checked that version
\* with GitHub itself — entered here, or received and verified here.
ShownWasChecked ==
    \A d \in Devices :
        held[d].verified => <<held[d].tok, held[d].stamp>> \in checked[d]

\* With nothing in flight, owed or half-applied, every device holds the same
\* token, or none, at the same stamp: a disconnection reaches every device
\* as a connection does, even one the outbox refused at first.
Converged ==
    (msgs = {} /\ \A d \in Devices : ~owed[d] /\ applying[d] = Idle) =>
        \A a, b \in Devices :
            /\ held[a].tok = held[b].tok
            /\ held[a].stamp = held[b].stamp

\* A change made on a device outranks the version it was made over, however
\* far that device's clock is behind the one that made the held version: the
\* user's last action there is what that device keeps, and sends.
LocalChangeOutranks ==
    [][changes' = changes + 1 =>
         \A d \in Devices : held'[d] # held[d] => held'[d].stamp > held[d].stamp]_vars

\* What a device holds never goes back to an older version: no received
\* version overwrites a newer one written in the meantime.
StampNeverGoesBack ==
    [][\A d \in Devices : held'[d].stamp >= held[d].stamp]_vars
=============================================================================
