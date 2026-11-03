# GitHub — Create the Token From Lotti

> **Status:** proposal.
> **Date:** 2026-11-03
> **Scope:** the GitHub settings page (`lib/features/github/ui/github_settings_page.dart`),
> one pure URL builder, its localized copy, and the GitHub docs.

Connecting Lotti to GitHub today means leaving the app, finding *Settings →
Developer settings → Personal access tokens* on github.com, creating a
fine-grained token, ticking the right permissions by hand, and pasting the
result back. The permission step is where people get lost: the settings page
has to spell out which boxes to tick, and still cannot point at them.

This plan adds one button to the settings page — **Create a token on GitHub**
— that opens GitHub's token form with the name, description, expiry and
read-only permissions already filled in. The user picks their repositories,
generates the token and pastes it, exactly as today. Everything after the
paste is unchanged.

It is the first of two steps. The second, a real *Sign in with GitHub*
through a Lotti GitHub App and the OAuth device flow, needs a GitHub App
registered by the maintainer and is planned separately; nothing here is in its
way, and the paste field this plan improves stays as that sign-in's fallback.

---

## What GitHub supports

Since August 2025 the fine-grained token form takes its fields from the query
string ([changelog](https://github.blog/changelog/2025-08-26-template-urls-for-fine-grained-pats-and-updated-permissions-ui/),
[docs](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)):

| Parameter | Value | Rule |
|---|---|---|
| base | `https://github.com/settings/personal-access-tokens/new` | — |
| `name` | token display name | ≤ 40 characters |
| `description` | free text | ≤ 1024 characters |
| `target_name` | user or organisation slug | defaults to the user's own account |
| `expires_in` | `1`–`366`, or `none` | defaults to 30, or less under an owner's lifetime policy |
| `<permission>` | `read` / `write` / `admin` | per permission, e.g. `pull_requests=read` |

Every parameter is optional and validated by the form. There is **no
parameter for repository selection** — the user still chooses which
repositories the token reaches — and **no permission for check runs**: GitHub
offers fine-grained tokens none, which is why CI can be incomplete on a
private repository (`GitHubClient._checkRunsOrHidden`). The classic token's
`scopes=` pre-fill is undocumented ("a hidden feature"), so this plan does not
link to it.

## The URL

```text
https://github.com/settings/personal-access-tokens/new
  ?name=Lotti
  &description=Lotti reads the pull requests you link to tasks.
  &expires_in=366
  &pull_requests=read
  &statuses=read
  &metadata=read
```

Decisions:

- **Exactly what the client reads, read-only.** `GitHubClient` reads pull
  requests, reviews, the combined commit status and check runs, and lists open
  pull requests. That is `pull_requests=read` and `statuses=read`;
  `metadata=read` is mandatory on every fine-grained token and is named so the
  form shows it rather than adding it silently. Nothing is `write`.
- **`expires_in=366`, not GitHub's 30.** The token syncs to the user's other
  devices, so renewing it is a chore on every one of them; a 30-day default
  means the tracking quietly stops every month. 366 is the longest a
  non-`none` value can be. `none` is refused by owners with a lifetime policy,
  where 366 is clamped instead. When it does expire, GitHub answers 401, the
  page already says *"GitHub rejected the token. It may have expired or been
  revoked."*, and the same button is right there to make the next one.
- **No `target_name`.** A fine-grained token reaches one owner. Lotti could
  guess it from the repositories assigned to categories, but a user with
  repositories under two owners would get the wrong one, and an owner the user
  is not a member of makes the form show an error. GitHub's default — the
  user's own account — is the safe one; the user changes it in the form.
- **The description is English and fixed.** It is shown on github.com, in a
  list the user manages there, not in Lotti; the copy in Lotti is localized.

## What the page looks like

```text
┌─ GitHub ───────────────────────────────────────────────┐
│ Lotti reads the pull requests you link to tasks with a │
│ read-only token from your GitHub account. Create one   │
│ on GitHub — the permissions are filled in for you —    │
│ choose your repositories, then paste the token here.   │
│                                                        │
│ [ ↗ Create a token on GitHub ]          (secondary)    │
│                                                        │
│ ┌ Personal access token ───────────────────────── 👁 ┐ │
│ └────────────────────────────────────────────────────┘ │
│ [ 🔑 Connect ]                          (primary)      │
│                                                        │
│ CI checks of private repositories may be incomplete:   │
│ GitHub gives such tokens no access to check runs.      │
│                                                        │
│ 🔒 The token syncs end-to-end encrypted …              │
└────────────────────────────────────────────────────────┘
```

- The button shows whenever the paste field shows — not connected, and also
  when a synced token was rejected — and never while connected.
- Leading icon `LottiIcons.openExternal`, `DesignSystemButtonVariant.secondary`,
  full width like Connect, so the two steps read as one column.
- The private-repository CI caveat moves out of the intro into its own
  secondary line under Connect: it is advice for after the token exists, and
  the intro should say only how to get one. The classic-token sentence goes —
  the button makes the fine-grained token the path, and the caveat says what
  it cannot do.
- If the browser cannot be opened (`launchUrl` returns false or throws), the
  page says so inline in the field's error slot, with the URL's host, and the
  user can still create the token by hand.

---

## The branch stack

```text
main
 └─ docs/github-token-template-plan        this plan
     └─ feat/github-token-template-url      Task 1: the URL builder
         └─ feat/github-token-create-button Task 2: the button, copy, docs   ← HEAD, the one changelog fragment
```

Each branch is one pull request based on the one below it. Only the head
branch carries a `changelog.d/` fragment, so the stack ships one release note.
Review fixes land as amends on the branch they belong to, and the branches
above are restacked.

---

## Task 1 — the URL builder

**Branch:** `feat/github-token-template-url` on `docs/github-token-template-plan`.

New `lib/features/github/domain/github_token_template.dart`, pure Dart, no
Flutter import:

```dart
/// The GitHub form that creates the token Lotti needs, with its name,
/// description, lifetime and read-only permissions filled in.
Uri gitHubTokenTemplateUri();
```

- Builds with `Uri.https('github.com', '/settings/personal-access-tokens/new', {...})`
  so encoding is the `Uri` class's job, not string concatenation.
- The permissions are one `const` map next to it, each entry documented with
  the `GitHubClient` call that needs it, so a new endpoint in the client has
  an obvious place to add its permission.
- Asserts in debug that `name` ≤ 40 and `description` ≤ 1024 characters —
  GitHub's limits, which a silent truncation would break.

**Test** — `test/features/github/domain/github_token_template_test.dart`:

- scheme `https`, host `github.com`, path `/settings/personal-access-tokens/new`;
- `queryParameters` equal exactly the expected map — so a permission added or
  widened to `write` fails the test, not just one missing;
- no value is `write` or `admin` (the read-only invariant, stated on its own);
- `expires_in` is `366`, and `name`/`description` are within GitHub's limits;
- the encoded string round-trips: `Uri.parse(uri.toString()) == uri`.

No changelog fragment, no doc change (nothing user-visible yet; the README's
file list gains the file in Task 2, together with its caller).

## Task 2 — the button, the copy and the docs

**Branch:** `feat/github-token-create-button` on `feat/github-token-template-url`.

**Code** — `lib/features/github/ui/github_settings_page.dart`:

- the secondary button above the token field, opening `gitHubTokenTemplateUri()`
  with `launchUrl(uri, mode: LaunchMode.externalApplication)`;
- a launch that returns false or throws sets the inline error to the new
  "could not open" message; it never throws out of the handler;
- the intro text replaced, the CI caveat as its own line under Connect, both
  in `tokens.typography.styles.body.bodySmall` / `text.mediumEmphasis` like
  the privacy line; spacing from `tokens.spacing.step*` only.

**Copy** — new and changed keys, in **every** catalog under `lib/l10n/`, in
the informal register (Romanian excepted), per
[localization](../../knowledge/conventions/localization.md):

| Key | English |
|---|---|
| `githubTokenIntro` (changed) | Lotti reads the pull requests you link to tasks with a read-only token from your GitHub account. Create one on GitHub — the permissions are filled in for you — choose your repositories, then paste the token here. |
| `githubCreateTokenButton` (new) | Create a token on GitHub |
| `githubCreateTokenOpenFailed` (new) | Lotti could not open your browser. Create the token on github.com under Settings → Developer settings → Personal access tokens. |
| `githubTokenChecksCaveat` (new) | CI checks of private repositories may be incomplete: GitHub gives these tokens no access to check runs. |

Then `make l10n` and `make sort_arb_files`.

**Tests** — `test/features/github/ui/github_settings_page_test.dart`, with
`MockUrlLauncher` from `test/mocks/mocks.dart` as `UrlLauncherPlatform.instance`
(restored in `tearDown`):

- not connected: the button shows; tapping it launches exactly
  `gitHubTokenTemplateUri()` as an external application;
- connected: no button;
- a synced token GitHub rejected: the button shows beside the rejection;
- the launcher returns false → the "could not open" message in the field's
  error slot; the launcher throws → the same, and no error escapes the test;
- typing in the field clears that message, as it clears any other;
- the caveat line shows under Connect and not while connected.

Re-run the launch-failure tests with the catch removed to see them fail.

**Docs:**

- `lib/features/github/README.md` — the setup paragraph ("A token GitHub
  accepts, added under Settings → Advanced Settings → GitHub …") says the page
  opens the pre-filled form; the file list gains `domain/github_token_template.dart`.
- `knowledge/features/github.md` — *The token and the client*: how the token
  is made (the template, its permissions, the 366-day choice and why there is
  no `target_name`), with a `sources` entry for the new file;
  `make knowledge_check`.
- `knowledge/features/settings.md` — its settings-tree diagram still shows
  `GitHub — if enableGitHubPullRequests`, a flag that no longer exists in
  `lib/` (the README: "There is no config flag"). Drop the condition.

**Changelog** — the stack's only fragment,
`changelog.d/2026-11-03-github-create-token-link.md`:

```markdown
### Changed
- **Connecting GitHub no longer means hunting for the right token settings.**
  Settings → Advanced Settings → GitHub has a "Create a token on GitHub"
  button that opens GitHub's token form with Lotti's name, a one-year expiry
  and the read-only pull request and commit status permissions already
  filled in. Choose your repositories, create the token and paste it back.
```

`make changelog_check`.

**Screenshots** — before/after of the GitHub settings page, phone and desktop,
not connected, with the `app-screenshots` harness. `before/` is captured from
`main` first.

---

## Verification, per branch

- `dart-mcp.analyze_files` clean, `fvm dart format .`.
- Only the touched test files: Task 1 the template test, Task 2 the settings
  page test (and the template test again).
- Task 2: `make l10n`, `make knowledge_check`, `make changelog_check`, the
  CI analyze validators (`tool/*/validate.dart`), and one real run on macOS:
  the button opens the browser on the filled form, a token made there connects.
- After every test run: `git checkout -- lib/l10n/app_localizations_*.dart
  ios/Podfile.lock` on Task 1; on Task 2, which changes ARB files, `make l10n`
  instead.

## Out of scope

- **Sign in with GitHub** (GitHub App + device flow) — the next plan; needs
  the app registered and the cross-device token decision first.
- Reading the token from the clipboard when the app regains focus.
- Pre-filling `target_name` from the categories' repositories.
- A classic-token link — its pre-fill is undocumented.
