---
name: beads
description: Use for authorized Lotti maintainer work that needs private durable task tracking, issue dependencies, blocker management, multi-session handoff, or shared agent memory. Public contributors use GitHub Issues instead.
---

# Beads

Use Beads as the private durable task system for authorized Lotti maintainers.
Public bugs, feature requests, and contributor coordination stay in GitHub
Issues. Local plans remain useful for the current turn.

## First Step

First confirm that the private tracker is available:

```bash
bd --readonly list --json
```

If no database exists and the current user is an authorized maintainer, run:

```bash
chmod 700 .beads
git config beads.role maintainer
bd bootstrap
```

If access is denied, do not initialize a competing database. Use GitHub Issues
and PR discussion instead.

Run `bd prime` manually when workflow context is needed. Do not install Git,
Codex, or Claude hooks for Beads in this repository.

## Core CLI Workflow

1. Pull and find work:

```bash
bd dolt pull
bd ready
bd list --status=open
bd list --status=in_progress
```

2. Inspect before editing:

```bash
bd show <id>
```

3. Claim work atomically:

```bash
bd update <id> --claim
```

4. Create durable follow-up work when implementation reveals new tasks:

```bash
bd create "Short title" --description="Why this exists and what needs to be done" --type=task --priority=2
```

5. Close completed work:

```bash
bd close <id> --reason="Completed"
```

6. With explicit authority, publish durable changes:

```bash
bd dolt push
```

## What Belongs In Beads

Maintainers use Beads for:

- shared project tasks
- blockers and dependencies
- discovered follow-up work
- work that must survive thread reset, compaction, or handoff
- status that another person or agent should be able to resume

Public-facing context must still be copied into GitHub issues, PR descriptions,
or review discussion so contributors never need private tracker access.

## Rules

- Do not use `bd edit`; it opens an interactive editor. Use `bd update` flags instead.
- Prefer `--json` when parsing `bd` output programmatically.
- Do not auto-close or mutate tasks unless the work is actually complete.
- Do not store credentials, private user data, or other secrets in Beads.
- Do not commit, push Git, or sync Dolt without explicit authority.
