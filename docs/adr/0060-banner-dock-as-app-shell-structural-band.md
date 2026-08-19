# ADR 0060: The Banner Dock Moves to the App-Shell Structural Band

- Status: Accepted — implemented. `_NudgeBannerTopLane` in
  `lib/beamer/beamer_app.dart` mounts the single `NudgeBannerDock` above the
  desktop sidebar and the mobile content; the bottom mini-player and its
  reserved lane are gone.
- Date: 2026-08-20

## Context

ADR 0055 Decision 5 shipped the banner channel on page-level surfaces and
explicitly held one option in reserve:

> An app-shell structural band (the demo-banner pattern) is documented as an
> escalation surface and deliberately not built in v1.

What was built instead — design handover 1b — was a bottom-docked mini-player:
on desktop the last child of the content column, beside (never under) the
sidebar; on phones a lane in the bottom overlay stack, riding above the
recording indicators and the five-slot nav bar.

That placement carried a standing cost. Because the dock shared the bottom
edge with the navigation bar, page-owned sticky action bars, the recording
indicators and the keyboard, every one of those had to be coordinated with
explicitly:

- `_MobileNavOverlayHeightScope` re-derived the dock's rendered height
  (`nudgeBannerDockReservedHeight`) from design-system dimensions and live
  text metrics, so page content and FABs would clear it at every text scale;
- that reserve had to mirror the dock's own visibility rule exactly, or a
  hidden banner left a blank strip above the nav bar;
- the dock yielded entirely while the keyboard was up, because it otherwise
  sat in the keyboard's space — and the reserve had to mirror *that* too;
- the dock had to be suppressed on routes whose own bottom surface takes over
  the edge.

Four coupled contracts, all of them existing only because the banner competed
for the bottom edge with everything else that wants it.

## Decision

1. **Take the escalation surface ADR 0055 reserved.** The dock mounts in an
   app-shell structural band at the top of the shell, using the demo-banner
   pattern that decision named: first child of a `Column` whose second child
   is the entire shell.

2. **Structural, never an overlay.** A speaking banner displaces the sidebar
   and the content rather than covering them. Scrolling content cannot pass
   under it, and it cannot collide with any bottom-edge surface, because it is
   not at the bottom edge.

3. **Full width, above the sidebar.** On desktop the band spans the window
   rather than sitting inside the content region, matching the demo strip.
   This supersedes handover 1b's "beside, never under, the sidebar".

4. **The band composes with the demo strip by nesting.** `_NudgeBannerTopLane`
   sits inside `DemoModeScaffold`, so with both active they stack — demo strip,
   then agent banner — with no coordination code between them.

5. **Delete the reserved-lane machinery.** The `Column` reserves space by
   existing, so `nudgeBannerDockReservedHeight` and the dock's contribution to
   the bottom-nav overlay height are removed rather than ported.

6. **Delete the keyboard yield.** It existed because the dock sat where the
   keyboard appears. At the top of the shell the keyboard never covers it, so
   a banner now stays readable while the user types.

7. **The dock stays mounted while collapsed.** Only the safe-area handling is
   gated on whether a banner speaks. Unmounting it would snap the last tenant
   away, and ADR 0058 makes that animated disappearance the visibility-action
   feedback.

## Consequences

- The four coupled bottom-edge contracts collapse to one structural
  invariant, and the collision class the mini-player lived with is gone by
  construction rather than by arithmetic.
- Escalation is the point: a structural band is harder to ignore than a
  bottom lane. ADR 0055's respect mechanics (Decision 4) are unchanged and now
  carry more of the weight — if banners start reading as intrusive, the
  mechanics to tune are frequency and cool-down, not placement.
- The band consumes vertical space at the top of every eligible surface while
  a banner speaks. On short phone viewports that is the most expensive space
  in the app; the quiet-by-default contract (ADR 0055 Decision 5) is what
  keeps the cost occasional.
- Ratings, exposure metering, rotation and the per-surface gate are untouched:
  this ADR moves where the dock is mounted, not what it says or when.

## Related

- [ADR 0055](./0055-banner-nudge-attention-channel.md) — the channel, and the
  escalation surface this ADR takes.
- [ADR 0058](./0058-procedural-text-banners-no-generative-imagery.md) — the
  procedural text banners, including the collapse-as-feedback contract.
- [ADR 0059](./0059-relationship-agent-runtime-and-nudge-generalization.md) —
  the kind-agnostic substrate and the per-surface gate.
- [knowledge/features/nudges.md](../../knowledge/features/nudges.md) — how the
  lane is built.
