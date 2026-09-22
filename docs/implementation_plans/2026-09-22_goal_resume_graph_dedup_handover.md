# Handover: goal-agent resume and graph neighbour deduplication

Date: 2026-09-22. Repository: `matthiasn/lotti`.

Implement these as two independent, narrowly scoped fixes, in this order:

| Priority | Beads | Outcome |
| --- | --- | --- |
| P1 | `lotti3-x7j.1` | A locally resumed goal agent immediately listens to its signals again. |
| P1 | `lotti3-85o.1` | Multiple relationships to one neighbour do not duplicate its displayed node or inflate aggregate counts. |

## Starting state and evidence

Both issues are open and dependency-ready. This session inspected source and
reconciled Beads; it did not implement either fix or run their tests. Treat the
regressions below as work to write and prove, not existing passing coverage.

The inspected checkout is `/home/parallels/github/lotti3`, on `main` at
`35fa5b75e4`. A fetch updated `origin/main` to `61c0656d40` (release 1.1.22,
PR #4422); local `main` is 37 commits behind. The principal source files for
these two defects are unchanged across that difference. Refresh these facts
before implementation and start each branch from current `origin/main`.
Preserve this handover and any subsequent local changes.

The earlier tracker cleanup closed 14 completed entries and updated 17 others.
Those changes are local to Beads; Dolt was not synced. Re-read each issue with
`bd --readonly show <id>` and load `.agents/skills/beads/SKILL.md` before using
the tracker. This handover does not grant new commit, push or Dolt-sync authority.

Read `AGENTS.md`, `test/README.md` and
`knowledge/conventions/testing.md` before editing. Use the feature concepts
linked below for context, verifying their claims against source.

## 1. Restore the owning runtime when resuming a goal agent

### Defect

`AgentControls._resumeAgent` awaits `AgentService.resumeAgent`, then always calls
`TaskAgentService.restoreSubscriptionsForAgent`. That service has a project-agent
branch, but otherwise restores `agent_task` links. Goal agents need goal-signal
subscriptions, so the identity becomes active while those subscriptions stay
absent. Restart or a later synced identity can repair them.

`GoalRuntimeMaintenance.onIdentityReceived` already handles the relevant repair:
it checks kind and lifecycle, watches check-ins, recovers pending chat and
registers signal subscriptions from the current goal criteria. Its non-active
branch removes subscriptions. The shared controls currently do not invoke it.

### Read these files

| Purpose | Path |
| --- | --- |
| Broken UI action | `lib/features/agents/ui/agent_controls.dart` |
| Lifecycle transition and its boolean result | `lib/features/agents/service/agent_service.dart` |
| Existing task/project restoration | `lib/features/agents/service/task_agent_service.dart` |
| Feature-neutral maintenance contract | `lib/features/agents/state/agent_runtime_registry.dart` |
| Goal-specific repair | `lib/features/goals/runtime/goal_runtime_maintenance.dart` |
| Composition-root registry wiring | `lib/app_bootstrap.dart` |
| Existing sync dispatch precedent | `lib/features/sync/matrix/sync_event_processor_agent_handlers.dart` |
| Architecture | `knowledge/features/goals.md`, `knowledge/features/agents/wake-orchestration.md` |

### Implementation direction

1. Trace the action through durable identity persistence, then obtain the
   current persisted identity. Do not pass the widget's dormant lifecycle or a
   cached pre-resume identity into a hook that gates on active lifecycle.
2. Restore through the existing feature-neutral maintenance boundary. The
   registry is a list of contributors, not a kind-keyed map: contributors guard
   their own kind, as in sync dispatch. Preserve task/project restoration.
   Avoid importing the Goals feature into shared agent controls; the registry
   exists specifically to prevent that dependency cycle.
3. Decide the smallest coherent location for local identity-change dispatch.
   If reusing `onIdentityReceived` for local changes, update its sync-only
   documentation and relevant concept. A new general lifecycle framework is
   unnecessary for this fix.
4. Respect `resumeAgent` returning false for a missing identity. Re-read
   lifecycle before restoring so a subsequent pause/destroy is not treated as
   an active goal. Preserve the existing busy/error behavior and invalidation.
5. Check async failure boundaries. A persistence/outbox exception may require
   a separate reconciliation fix; inspect related `lotti3-x7j` tasks before
   expanding this ticket. Do not swallow failures or report a successful
   restoration without evidence.

### Regression evidence to produce

Extend `test/features/agents/ui/agent_controls_test.dart`. Its current resume
test only verifies the task-service call, so it cannot detect this bug.

- Resume a dormant goal through the actual control. Prove the owning runtime
  receives the persisted active identity after resume completes. Use a
  controlled future to distinguish completion from mere invocation order.
- Prove a representative signal can reach the resumed goal without restarting
  or delivering a sync identity. Place this at the narrowest existing runtime
  or service test boundary; mocked dispatch alone is not end-to-end evidence.
- Preserve task-agent restoration and the existing project-agent behavior.
- Cover a missing agent/false return, failure of the resume operation, and an
  identity that is non-active when reconciliation reads it. Assert that none
  incorrectly registers an active goal subscription.
- Re-run each new fix-specific regression with the production fix reverted and
  confirm the relevant failure, then restore the fix and pass it again.

Candidate additional test files, only if their corresponding code is touched:
`test/features/goals/runtime/goal_runtime_maintenance_test.dart`,
`test/features/agents/state/agent_runtime_registry_test.dart`,
`test/features/agents/service/agent_service_test.dart`, and
`test/features/agents/service/task_agent_service_test.dart`.

Done means local resume restores real goal subscription behavior, task/project
behavior remains correct, and focused validation passes. Keep unrelated
re-analysis, destroy and visual redesign work out of this PR.

## 2. Deduplicate displayed graph neighbours and aggregate membership

### Defect

`buildLocalGraphProjection` appends one `_Neighbor` per incident edge. Two typed
relations or reciprocal edges can therefore produce two entries for one node.
The individual-emission loop appends both and spends the node budget twice;
hidden membership and `aggregateCount` likewise count entries rather than
distinct nodes. The second-hop path has a set guard, but the direct path does
not. The photo aggregate also derives member IDs from this direct list.

Multi-edge input is valid: `TaskGraphProvider.addEdge` keys by
`from|to|kind`. Fix the projection without deleting legitimate relationships.

### Read these files

| Purpose | Path |
| --- | --- |
| Projection, grouping, budgets, media and ordering | `lib/features/knowledge_graph/domain/graph_projection.dart` |
| Graph data and current degree calculation | `lib/features/knowledge_graph/domain/graph_models.dart` |
| Raw edge construction | `lib/features/knowledge_graph/state/task_graph_provider.dart` |
| Primary regression suite | `test/features/knowledge_graph/domain/graph_projection_test.dart` |
| Architecture | `knowledge/features/knowledge_graph.md` |

### Implementation direction

1. Normalize eligible direct neighbours by node ID before they consume a
   display budget or become aggregate members. A set guard only in the final
   append loop is insufficient: precomputed capacities and hidden tails would
   still contain duplicates.
2. Apply edge/node filters before choosing a representative relationship. A
   filtered-out high-priority edge must not hide a neighbour that still has an
   eligible relationship.
3. Define deterministic ownership when one neighbour belongs to several typed
   relation groups. Existing `_compareNeighbors` and `_edgePriority` supply a
   useful ordering. Ensure a node is not both visible and counted as hidden,
   or counted in multiple collapsed groups. Document the chosen rule.
4. Preserve valid typed raw edges between visible endpoints. Deduplicating
   displayed nodes does not authorize collapsing different relationship kinds.
5. Apply the unique-membership invariant to collapsed photos and expansion,
   while preserving filtering, cover exclusion and missing-image behavior.
6. Treat degree separately: `degreeMap` currently counts incident edges. Node
   deduplication does not change that definition. Decide explicitly whether
   distinct-neighbour degree belongs in this fix; otherwise record it as a
   follow-up. Do not silently erase typed edges to change node size.

### Regression evidence to produce

Extend the existing projection test file using its deterministic node helper.

- Two different typed edges to the same neighbour emit that neighbour once.
- Reciprocal association edges emit one neighbour and unique membership.
- A crowded graph with six distinct neighbours and two edges per neighbour,
  forced into a small budget, reports the true hidden set. For a fixture that
  shows two neighbours individually, the aggregate must contain the other four
  exactly once. Assert actual IDs, not only count/member-list agreement.
- A neighbour crossing relation groups is neither emitted twice nor included
  in an aggregate after becoming visible. Permuting the input edge order
  preserves node/group membership and counts.
- Filters still expose a neighbour through its remaining eligible edge.
- Photo membership remains unique through collapse and expansion.
- Assert the node budget, unique visible IDs, disjoint visible/hidden sets,
  unique aggregate members and preservation of meaningful visible typed edges.
  Add appropriately tagged property coverage where useful for the pure logic.
- Prove the new multi-edge regressions fail with the fix reverted.

Do not broaden into provider persistence or renderer changes unless the tests
demonstrate they are required. The separate layout-navigation defect,
`lotti3-85o.7`, was already fixed by merged PR #3824 and is closed.

## Validation and delivery for each fix

Use two branches/PRs and keep their evidence separate. Both can start from
current main; neither depends on the other. Claim the relevant Beads issue
when implementation actually starts.

- Register the workspace with dart-mcp. Analyze with absolute paths, format
  with `fvm dart format .`, and run the test files for touched source through
  dart-mcp. Do not run the entire agents or graph suite locally.
- Reuse shared mocks, fallbacks and widget hosts. Follow the fake-time and
  async-completion contracts in the testing convention.
- Update the relevant knowledge concept with the final behavior and run
  `make knowledge_check`. Do not set your own concept's `verified` field.
- Add one user-facing `changelog.d/` fragment per fix and run
  `make changelog_check`. Leave release-owned version/changelog/metainfo files
  to the release workflow.
- The graph fix changes visible counts/layout: load the `app-screenshots`
  skill and capture the multi-edge surface from the base commit before edits,
  then capture the same fixture afterward. Use synthetic/penguin data, stage
  images outside version control and follow the publishing convention. For
  the resume fix, capture before/after if the implementation changes a visual
  surface. No new styling is needed to fix subscription routing.
- Once authorized to create/update a PR, own it until checks and required
  coverage are green, actionable review threads are addressed and resolved,
  and the PR is mergeable. Record the PR, tested commit and red/green evidence
  in Beads; close on completion with merge evidence.

Reference conventions: `knowledge/conventions/screenshots.md`,
`knowledge/conventions/localization.md`, and `changelog.d/README.md`.
