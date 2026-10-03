# GitHub

Links GitHub pull requests to tasks, so the work an AI coding assistant did
flows back into the task without screenshots: the pull request's description,
status, checks, merge conflicts and reviews sit beside the task, go into the
next coding prompt, and back the task agent's suggestions of which checklist
items are done.

## What it does

- **Links a pull request to a task**, by pasting its URL, or with the picker
  that lists the open pull requests of the repository assigned to the task's
  category or project.
- **Keeps a snapshot** of each linked pull request in the journal: a
  `PullRequestEntry` linked from the task, carrying when GitHub observed it.
  It syncs like any entry, so a device without a token still shows what a
  device with one last saw, labelled with its age.
- **Refreshes it whenever it enters a task context** — a coding prompt or a
  task-agent wake — and when the user asks. A failed refresh writes nothing,
  and the context then says the status could not be refreshed.
- **Grounds checklist suggestions** in a pull request that was just refreshed.
  The agent proposes them through the existing checklist tool and the user
  confirms each one.
- **Shows merged and closed pull requests in brief** in those contexts: their
  outcome, size and a TL;DR, which the task agent's model writes once, where
  the task's category allows automatic inference. Open ones keep every
  detail.

## What it owns, and what it delegates

It owns the pull request snapshot and its ordering, the GitHub client, the
token, the refresh, and the pull request section of the task.

It delegates storage and sync to the journal: `updateJournalEntity` merges
two concurrent versions of a pull request entry with this feature's
`mergeConcurrentPullRequestVersions` instead of raising a conflict.
Suggestions go through the task agent's change sets, and prompts through the
skill prompt builder.

## Privacy

The token is the user's own read-only personal access token. It lives in
the device keystore and syncs to the user's other devices end-to-end
encrypted, like an inference provider's key; a token that arrives is checked
with GitHub before it is used as connected. It is sent only to
`https://api.github.com`, and never logged or exported. Pull request web pages
are never fetched.

## Where the code sits

```text
lib/classes/pull_request_data.dart        PullRequestData, PullRequestSnapshot
lib/features/github/
  api/github_client.dart                  REST reads, stamps, failures, rate limit, ETags
  api/pull_request_mapper.dart            responses to a PullRequestSnapshot
  context/                                refresh and render pull requests for task contexts
  domain/pull_request_ref.dart            parsing a pasted pull request
  domain/github_repository.dart           parsing a category's owner/repo
  domain/open_pull_request.dart           what the picker lists
  domain/pull_request_order.dart          observation order, digest, concurrent merge
  domain/pull_request_write_rule.dart     when an observation is written
  domain/pull_request_summary_input.dart  what a summary is written from, and matched by
  repository/github_token_storage.dart    the token in the keystore
  repository/pull_request_repository.dart link, unlink, track, persist an observation, summaries
  service/pull_request_service.dart       link a pasted pull request, refresh one
  service/pull_request_summarizer.dart    the TL;DR of a merged or closed pull request
  state/github_providers.dart             providers, account, token status, refresh
  ui/                                     settings page, task card, row, link modal,
                                          the Add sheet's tracking row
```

There is no config flag. A token GitHub accepts, added under Settings →
Advanced Settings → GitHub, makes pull requests trackable. A task shows its
Pull requests section once the user picks "Pull request tracking" from the
"+" of its action bar — a choice stored on the task, so it holds on every
device — or while a pull request is linked to it. A category names its
repository; the "+" picker lists that repository's open pull requests no
task holds; a pasted pull request another task holds is linked here too only
once the user confirms it. Coding prompts and task-agent wakes carry the
task's pull requests, refreshed for them. The concept below describes all of
it.

## Further reading

- [GitHub pull requests](../../../knowledge/features/github.md) — the
  architecture: the entry, ordering, refresh, merge, client and context.
- [`PullRequestSnapshot`](../../../specs/tla/README.md) — the design model
  and the counterexample behind each of its rules.
