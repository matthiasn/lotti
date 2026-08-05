# Demo mode

Demo mode lets a new user explore a fully working Lotti — the Intergalactic
Penguin Logistics play world — without committing any real data. The demo is
a separate sandbox world with its own databases and files; nothing in it ever
mixes with the real journal, and nothing syncs.

## What it does for the user

- **A populated app from the first second.** Tasks with cover art, checklists,
  logged time, labels, and a fictional AI setup — plus a guided "first
  mission" checklist with five concrete things to try.
- **Three ways in.** The onboarding welcome ("Explore with sample data"), the
  tasks empty-state button, and Settings → Onboarding.
- **Always clearly marked.** A persistent banner sits above the app while the
  demo is active; tapping it (or its Exit button) opens the exit sheet.
- **Exit without losing work.** Leaving keeps the demo world resumable, and
  the exit sheet offers to copy demo-created tasks, entries, and connected AI
  setup into the real journal. Reset and Delete are separate, explicit
  settings actions.
- **Real AI as an opt-in step.** The seeded AI configs are fictional; the
  first AI tap (or a settings row) offers the guided flow to connect a real
  provider — inside the demo only, until copied over on exit.

## Module map

```text
lib/features/demo/
├── seed/    penguin-logistics fixture + locale tables, DemoSeeder,
│            seed manifest, tutorial "first mission" content
├── state/   DemoModeGateway — enter/resume/reseed/exit/delete decisions
├── ui/      banner + scaffold, entry launcher & Try button, exit sheet,
│            real-AI setup sheet
├── ai/      real-AI availability gate (nudge decision)
└── copy/    exit copy-over: candidate discovery + the copier
```

The `seed/` fixture doubles as the manual's deterministic screenshot fixture —
`penguinLogistics()` output must stay pixel-identical, so demo-only content is
added via `DemoTutorialContent`, never to the fixture itself.

## What it delegates

The demo does not know how to create, isolate, or switch worlds. The profile
registry, the guest-world isolation contract (no sync stack, own host ID,
single path authority), `WorldHandle`, and the in-app switch all belong to
[`lib/features/profiles/`](../profiles/README.md).

## How it works

The seed manifest lifecycle, copy-over closure semantics and v1 exclusions,
the real-AI nudge, and the content-ownership rule are documented in the
knowledge bundle:

**→ [knowledge/features/demo.md](../../../knowledge/features/demo.md)**
