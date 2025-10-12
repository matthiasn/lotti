Sync V2 Reliability Tracker — 2025-10-12

Context
- After overnight sleep or during early sessions, some updates (flag changes, checklist items/updates, entry links) occasionally fail to land on the receiving device.
- Matrix Stats “skipped” did not reflect these misses (they weren’t being processed at all, not deliberately skipped).

Observed Symptoms
- First few actions succeed, then one or more updates go missing (no later catch‑up).
- Not specific to entry links; affects journalEntity updates (flags, date/time edits) and checklist operations.

Primary Hypotheses (and Status)
1) Marker advancement skipping payloads (ordering/SDK delivery quirks)
   - Root cause: marker used to advance on any event (including non‑sync). Late non‑sync events could jump the checkpoint past pending sync text messages.
   - Mitigation (landed): advance only on sync payloads (custom msgtype or fallback‑decoded payload). Add heartbeat rescan + focused catch‑up when marker not in current window.

2) Transport/time‑of‑delivery gaps from SDK timeline
   - Symptoms: devices sleeping/waking show partial delivery; live callbacks suppressed intermittently.
   - Mitigation (landed): periodic live rescan every 5s; if marker not found, perform catch‑up window. Metrics: heartbeatScans, markerMisses.

3) Apply‑time discard (vector clocks)
   - Explanation: last‑writer‑wins; older/same updates ignored. This should settle if newer arrives.
   - Visibility (landed): DB‑apply counters — dbApplied, dbIgnoredByVectorClock, conflictsCreated. Per‑type attribution still visible via processed.* and droppedByType.*

What We Changed (landed)
- Marker advancement: sync‑only advancement (including fallback‑decoded sync JSON) to prevent silent skips.
- Fallback decode: process valid base64 JSON SyncMessage even without custom msgtype.
- Attachment counting: attachments no longer inflate “skipped”; still counted under prefetch.
- Per‑type metrics: processed.<type>, droppedByType.<type>.
- DB‑apply metrics: dbApplied, dbIgnoredByVectorClock, conflictsCreated.
- Heartbeat rescan (every 5s) + marker recovery via catch‑up on misses.
- UI: Matrix Stats shows typed metrics incl. DB‑apply; legend tooltip; added “Force Rescan” and “Copy Diagnostics”.

How To Verify (receiver side)
1) After performing edits on sender, open Matrix Stats on receiver:
   - processed.<type>: increments for the operation type performed (journalEntity, entryLink, etc.).
   - dbApplied/dbIgnoredByVectorClock/conflictsCreated: whether DB wrote/ignored/flagged conflict.
   - markerMisses/heartbeatScans: whether recovery paths triggered.
2) Use Force Rescan if updates seem missing — triggers rescan + catch‑up.
3) Use Copy Diagnostics to capture snapshot for bug reports.

Current Risks / Unknowns
- SDK live timeline callbacks can be suppressed on some platforms after sleep; periodic rescan should mitigate, but we need field confirmation.
- Vector‑clock ignores will appear as dbIgnoredByVectorClock; if these correlate with transcripts/checklist arrays, we may need field‑aware merges.

Next Actions (proposed)
- Adaptive heartbeat: tighten after markerMisses, relax when stable; optionally pause when backgrounded.
- Optional ACK design (offline‑safe):
  - Soft acks via “latest applied vector clocks” surfaced in diagnostics (no extra events).
  - If needed, introduce minimal com.lotti.sync.ack events sampled (e.g., 1/N) to guide sender retry priority.
- Field‑aware merges:
  - Transcripts, checklist arrays: merge/append semantics vs overwrite.
  - Keep flags/dates last‑writer‑wins.

Debugging Runbook
- If missing updates are reported:
  1) Capture Matrix Stats: processed.*, dbApplied, dbIgnoredByVectorClock, conflictsCreated, heartbeatScans, markerMisses.
  2) Copy diagnostics and attach logs showing: liveScan processed=…, apply rows=… status=…
  3) Try Force Rescan; confirm state convergence.
  4) If dbIgnoredByVectorClock increments for array‑like fields, consider field‑aware merge edge.

Open Questions
- How frequently do markerMisses occur across devices? (Collect anonymized counts)
- Do missed updates cluster around specific types (checklist, transcripts)?
- Does adaptive heartbeat significantly reduce markerMisses without noticeable battery impact?

