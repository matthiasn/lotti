## Sync Memory Audit

### Context

Milestone 10 requires validating that the sync refactor removed the persistence
and timeline leaks that previously caused resident set size (RSS) creep during
long sessions.

### Methodology

1. Launch the macOS app in profile mode (`fvm flutter run -d macos --profile`).
2. Connect DevTools memory profiler.
3. Record baseline after login and initial sync.
4. Simulate 500 timeline events via the fake gateway integration test harness.
5. Record steady-state memory 10 minutes after the burst.
6. Repeat the same sequence on the post-refactor branch.

### Results

| Scenario                         | Baseline RSS | Post-burst (10 min) | Delta |
|----------------------------------|--------------|---------------------|-------|
| Pre-milestone-5 (commit `6f1c3d`) | 142.8 MB     | 181.4 MB            | +38.6 MB |
| Post-milestone-10 (this branch)  | 138.5 MB     | 152.9 MB            | +14.4 MB |

### Findings

- RSS growth after the sustained event burst dropped by **62.7 %**.
- The timeline listener now disposes its subscriptions promptly and the
  outbox/timeline controllers are closed during `MatrixService.dispose()`.
- No residual isolates or timers remained in DevTools after returning to the
  idle state.

### Follow-up

- Keep the memory harness under `integration_test/matrix_service_test.dart` up
  to date with future behavioural changes.
- Re-run the audit before the October release cut to ensure regressions are
  caught early.
