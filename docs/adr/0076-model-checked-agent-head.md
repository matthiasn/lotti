# ADR 0076: The Agent Head Is a Register Over the Message DAG

- Status: Accepted
- Date: 2026-09-24

## Context

Every local append chains the new message off the agent's head pointer,
`AgentStateEntity.recentHeadMessageId`, and moves the pointer to the new
message (ADR 0016). The pointer is a field of the synced agent-state row.
ADR 0068 made the receive path join the row's G-counters and report
watermarks. ADR 0071 model-checked the message log and left one residual
open: the head pointer could still move back to an ancestor, because on
receive it was just another field of whichever state version won
last-writer-wins. The next append then forked the log off the old head. Fork
healing is off by default, so that fork could stay.

We extended `specs/tla/AgentMessageLog.tla` with the properties the head
should have and checked the code as it stood. TLC found three holes:

1. **Last-writer-wins moved the head back** (`HeadNeverRegresses`, four
   steps). The device whose clock runs ahead appends a root `b1`. The other
   device receives it, chains `a1` off it, and then receives the fast
   device's state row. That row is concurrent with its own and later on the
   skewed clock, so it wins, and with it the head `b1`. On dominance the
   incoming head also always won, even over a local head known to descend
   from it. A concurrent merge keeps the winner's clock, so a replica can
   hold a head that the writer of its successor never saw.
2. **An append chained off a head that already had a child** (`AppendsOffTips`,
   six steps). State rows and messages sync separately. A device that had
   received `a2` and its edge to `a1`, but only the state version naming
   `a1`, appended `b1` off `a1`. That is a fork, although this device already
   held `a1`'s successor.
3. **The receive was not one transaction** (`HeadNeverRegresses`, five
   steps). The sync processor read the local state row (from the bundle
   prefetch, or with one read), resolved the incoming version against it,
   and wrote the result later. An append by the executor that committed in
   between was overwritten, and the head moved back past it.

## Decision

1. **The head merges by ancestry, not by last writer.** Of two state
   versions' heads, `mergeAgentHeads` keeps the one that descends from the
   other in the local DAG. An unset head never wins. Two heads with no order
   known locally (a true fork, or rows still in flight) go by id. That pick
   depends only on the pair, never on clocks or arrival order (the lesson of
   ADR 0067's joined clocks). A dominating version keeps the local head when
   that head is known to descend from its own, or its own is unset.
   Otherwise it brings its own head. A version with no clock on either
   side (an older build's) still applies, as ADR 0068 has it, but with
   the heads merged the same way. Every other field of the row is resolved
   as before.
2. **The resolver stays pure; the caller reads the order.**
   `resolveAgentEntityVersions` takes an `isAncestor` oracle. The sync
   processor fills it from `AgentMessageDag.ancestryOf`: a forward walk over
   the `messagePrev` edges of present, live rows, the same edges the
   projection folds. It runs only for two state versions whose heads differ.
   The local write path needs no oracle, because every local head writer
   reads the row in its own transaction.
3. **An append chains off a tip.** `_appendMessage` first moves a set head
   past any child it has on this device (`AgentMessageDag.tipFrom`,
   following the lowest id at each fork). So a pointer that trails the log
   never forks it. This also settles what the merge could not know yet: a
   head left on a row whose child arrived later.
4. **A state version is received in one transaction.** The processor reads
   the local state row and its identity inside the transaction that writes
   the result, and never takes a state row from the bundle prefetch. A local
   append now waits for the receive, or the receive sees the append.
5. **The model gates the code.** `AgentMessageLog.tla` has one switch per
   decision (`HeadMerge`, `TipAppend`, `AtomicReceive`), and the Glados
   conformance trace drives the real services through the real receive
   decision.

## Consequences

- ADR 0071's residual, *"the head pointer can still move back"*, is closed.
  `HeadNeverRegresses` and `AppendsOffTips` hold in all three configurations.
  `SettledHead` also holds: once sync settles on one head, every device's
  next append chains off it. `EventuallySingleHead` still holds under fair
  delivery and healing. Setting any of the three switches back to `FALSE`
  reproduces its trace.
- A fork now needs two devices appending before either has seen the other's
  message. It can no longer come from a stale pointer.
- The pointers themselves need not agree once sync settles
  (`PointersConverge` is written down but not claimed). A merge made before
  the rows that order two heads arrived can leave a pointer on the older
  head. The next append advances past it, so this has no effect on the log.
- Costs:
  - Each append reads the links into the head once: one indexed query, and
    no more while the head is a tip.
  - A received state version whose head differs from the local one walks
    forward from both heads. That walk is short while the heads are near the
    tip, and at worst covers what is newer than the older head.
  - A state row in a bundle costs one read inside its transaction instead of
    a slot in the bundle prefetch.
- Residual: a message that syncs ahead of its own edge is not seen as its
  parent's child by the tip walk, so an append in that window forks. This is
  the window the fork healer's chain-edge gate already waits out. The message
  and its edge are written in one transaction and travel together in
  practice.
- No changelog entry. A fork has no surface of its own: the projection and
  every view order the log canonically, whatever its heads. An unhealed
  fork costs an on-device prompt prefix that does not re-warm, and context
  read across more than one head. Those are costs inside a wake, not
  behaviour a user sees.

## Related

- `specs/tla/AgentMessageLog.tla`, `specs/tla/README.md`
- `lib/features/agents/sync/agent_message_dag.dart`,
  `lib/features/agents/sync/agent_concurrent_resolver.dart`
- [Vector clocks and conflicts](../../knowledge/features/sync/vector-clocks-and-conflicts.md)
- [Agent memory and log compaction](../../knowledge/features/agents/memory-and-compaction.md)
- [ADR 0016: Agent state as log projection](./0016-agent-state-as-log-projection.md)
- [ADR 0018: Convergent multi-device execution](./0018-convergent-multi-device-execution.md)
- [ADR 0067: Model-checked change-set lifecycle](./0067-model-checked-change-set-lifecycle.md)
- [ADR 0068: Model-checked agent convergence](./0068-model-checked-agent-convergence.md)
- [ADR 0071: Model-checked agent message log and compaction](./0071-model-checked-agent-message-log.md)
