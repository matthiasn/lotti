# Projection kernel

A small, pure piece of the agents feature: given a **set** of agent log events, it
produces a canonical order and folds them into derived state.

It is here as its own unit because it proves one property the whole agent design
rests on:

> the same event set yields the same projected state, regardless of the order
> events arrived in or how the log branched.

If that holds, two devices that saw the same events in different orders end up in
the same place — which is what makes the append-only agent log safe to sync.

The kernel is pure Dart with no I/O, so it can be tested by shuffling event sets
and asserting the result never changes.

## How it works

**→ [knowledge/features/agents/projection.md](../../../../knowledge/features/agents/projection.md)**

For how the projection is used at wake time — reconciled state, multi-head
tolerance and fork healing — see
[knowledge/features/agents/memory-and-compaction.md](../../../../knowledge/features/agents/memory-and-compaction.md).
