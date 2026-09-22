# Private Maintainer Task Tracking

This repository uses Beads only for private maintainer implementation planning,
dependencies, handoffs, and durable agent memory. Public bugs, feature requests,
and contributor coordination remain in
[GitHub Issues](https://github.com/matthiasn/lotti/issues).

The canonical Beads database is an embedded Dolt database. It syncs to a
separate private repository through `refs/dolt/data`; the database is not stored
in this source branch and is not encrypted.

## Set up a new maintainer machine

The commands below assume a macOS or Linux shell, Git, and an authorized
maintainer account. Public contributors do not need this tracker.

### 1. Install a matching, embedded-capable Beads CLI

Run `bd version` on the existing machine and install the same supported release
on the new one. The working installation was checked on 2026-09-22 and reports
**1.1.0**. Use the matching operating-system and CPU archive from the
[official 1.1.0 release](https://github.com/gastownhall/beads/releases/tag/v1.1.0),
verify it against that release's `checksums.txt`, and put the extracted `bd`
executable on your `PATH` (for example, `~/.local/bin` on Linux).

For macOS/Linux, Homebrew is also supported:

```bash
brew install beads
bd version
```

Homebrew may install a newer release. Confirm that its version matches the
maintainer setup before opening the shared database; setting up a machine is
not the occasion for an uncoordinated schema upgrade. Prefer the matching
release archive when a package manager offers a different version.

Use an embedded-capable build. This repository's checked-in
[`metadata.json`](metadata.json) selects embedded Dolt, and the existing
installation works without a separate `dolt` executable. A server-only build
from `CGO_ENABLED=0 go install` is not an equivalent replacement. See the
[upstream installation guide](https://github.com/gastownhall/beads/blob/main/docs/getting-started/installation.md)
for platform installation and build variants.

### 2. Make sure the old machine's work has reached the private remote

Cloning the application source does not transfer local Beads changes. On the
existing machine, an authorized maintainer should publish any pending tracker
work before moving to the new machine:

```bash
bd dolt commit -m "Save tracker state before machine handover"
bd dolt pull
bd dolt push
```

The commit step is needed when changes remain in the Dolt working set; if there
is nothing to commit, proceed to pull. Resolve any pull conflicts before
pushing. Do not force-push to bypass them. These commands affect the private
tracker, independently of `git commit` and `git push` in the application repo.

If the old machine is unavailable, bootstrap can recover only what reached the
remote. A JSONL export is an issue interchange file, not a complete database
backup; use the installed release's `bd backup --help` for full recovery.

### 3. Set up access and clone Lotti

Register the new machine's SSH public key with the GitHub account that has
access to both the application and the private tracker. Keep private keys on
the machine. A working HTTPS login in `gh` alone does not establish SSH access.

```bash
git clone git@github.com:matthiasn/lotti.git
cd lotti
git config beads.role maintainer
chmod 700 .beads
```

If the clone already exists, enter its root instead of cloning again. Configure
your normal Git author name/email if they are not already configured; Beads
uses the Git user name as its default actor.

[`config.yaml`](config.yaml) supplies `sync.remote`, pointing to the separate
private tracker. Check access to its Dolt data ref before bootstrapping:

```bash
git ls-remote --exit-code git@github.com:matthiasn/lotti-beads.git refs/dolt/data
```

This must succeed and print a hash plus `refs/dolt/data`. Repository-not-found,
permission-denied, or an absent ref means access/configuration needs fixing.
The application's ordinary `origin/main` is not the Beads database.

### 4. Bootstrap from the existing tracker

First check whether a database is already available:

```bash
bd --readonly list --limit 5 --json
```

If it is, verify its identity and use the normal pull workflow. If the fresh
clone has no database, inspect bootstrap's plan:

```bash
bd bootstrap --dry-run
```

The plan must recover the configured existing private tracker. If it proposes
an empty database or an unexpected source, stop and fix the configuration.
Once the plan is correct:

```bash
bd bootstrap
bd --readonly dolt remote list --json
bd --readonly list --limit 5 --json
bd --readonly show lotti3-x7j.1 --json
bd --readonly show lotti3-85o.1 --json
```

Verify the Dolt remote matches `sync.remote` and existing `lotti3-…` issue IDs
are present. The two examples are known existing issues, whether open or
closed when you read this. A successful bootstrap into an empty tracker is
not a successful migration.

Do not run `bd init` or `bd init --force` when bootstrap or private-repository
access fails. That would create a competing database or risk existing data.
Do not copy a live database directory between machines.

### Troubleshooting

| Symptom | Next check |
| --- | --- |
| `bd: command not found` | Add the executable's directory to `PATH`, reopen the shell, and run `bd version`. |
| SSH permission denied | Check the loaded SSH key and that its GitHub account has private-repository access. |
| Bootstrap proposes a new database | Check `sync.remote` and the private `refs/dolt/data` ref before proceeding. |
| Missing recent edits | Publish them from the old machine, then run `bd dolt pull` on the new one. A source-code push does not sync Beads. |
| Embedded backend unavailable | Install the matching embedded-capable release build; do not convert this clone to server mode as a workaround. |
| Schema/version mismatch | Match the maintainers' CLI version and coordinate any migration with them; do not migrate independently on every clone. |

Run `bd doctor` for diagnostics and review its recommendations. Do not blindly
apply repairs that install hooks, initialize a new tracker, or migrate the
shared schema. The repository-specific agent workflow is in the
[Beads skill](../.agents/skills/beads/SKILL.md).

## Workflow

```bash
bd dolt pull
bd ready --json
bd show <id> --json
bd update <id> --claim --json
bd close <id> --reason "Completed" --json
bd dolt commit -m "Record completed tracker work"
bd dolt push
```

The angle-bracket IDs are placeholders. Commit pending Dolt working-set changes
before pushing; skip that step if there are none. Agents need explicit authority
for Dolt sync and Git commits/pushes, as described in `AGENTS.md`.

Run `bd prime` manually when agent workflow context is needed. This repository
deliberately does not install Git, Codex, or Claude hooks for Beads.

Beads contents are visible to everyone with access to the private remote. Never
store credentials, private user data, or other secrets in issues. To disable
Dolt usage metrics, set `DOLT_DISABLE_EVENT_FLUSH=1`.

See the
[Beads documentation](https://github.com/gastownhall/beads/tree/main/docs) for
storage, sync, backup, and upgrade procedures.
