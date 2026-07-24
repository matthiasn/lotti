# Private Maintainer Task Tracking

This repository uses Beads only for private maintainer implementation planning,
dependencies, handoffs, and durable agent memory. Public bugs, feature requests,
and contributor coordination remain in
[GitHub Issues](https://github.com/matthiasn/lotti/issues).

The canonical Beads database is an embedded Dolt database. It syncs to a
separate private repository through `refs/dolt/data`; the database is not stored
in this source branch and is not encrypted.

## Maintainer setup

1. Install the same supported Beads release used by the other maintainer
   (`bd version`; this setup was created with 1.1.0).
2. Ensure your GitHub SSH key has access to the private Beads repository.
3. From a fresh Lotti clone, run `chmod 700 .beads`.
4. Mark the clone as a maintainer workspace with
   `git config beads.role maintainer`.
5. Run `bd bootstrap`.
6. Verify access with `bd --readonly list --json`.

Do not run `bd init` when bootstrap or private-repository access fails. That
would create a competing local database.

## Workflow

```bash
bd dolt pull
bd ready --json
bd show <id> --json
bd update <id> --claim --json
bd close <id> --reason "Completed" --json
bd dolt push
```

Run `bd prime` manually when agent workflow context is needed. This repository
deliberately does not install Git, Codex, or Claude hooks for Beads.

Beads contents are visible to everyone with access to the private remote. Never
store credentials, private user data, or other secrets in issues. To disable
Dolt usage metrics, set `DOLT_DISABLE_EVENT_FLUSH=1`.

See the
[Beads documentation](https://github.com/gastownhall/beads/tree/main/docs) for
storage, sync, backup, and upgrade procedures.
