# Contributing to Lotti

Two things genuinely help: **issue reports** and **translations**. Both are
valued, and both are read.

## Code pull requests are not accepted

I do not merge outside code contributions. This is not a judgement on anyone's
work — it follows from three constraints:

- **Review capacity is the binding limit.** My review time, not ideas, is what
  gates what lands.
- **Lotti holds people's personal data on their own devices.** Accepting code I
  have not reviewed carefully is a risk taken on their behalf, not mine.
- **AI-generated code arrives faster than anyone can review it**, and varies
  wildly in quality. Reviewing it properly is expensive; accepting it incorrectly
  is easy.

An unsolicited code PR will be closed unmerged, with thanks and without review.
I would rather not waste your time, so I am saying it here rather than after
you have written the code.

**Open an issue instead.** A clear description of the bug, or of the idea and why
you want it, is genuinely more useful to me than a patch — and costs you far less.

Lotti is GPL-3.0. Fork it and build whatever you want on top for yourself.

## Translations are the exception

Translation pull requests **are** welcome, and are the one kind I merge.

- Strings live in the ARB catalogs under `lib/l10n/`. A new or corrected label
  belongs in **every** catalog, not a subset — the full list, the `app_en_GB`
  exception and the per-language register rules are in
  [knowledge/conventions/localization.md](knowledge/conventions/localization.md).
- The app addresses people **informally**, with Romanian as the deliberate
  exception. The concept above has the pronouns per language.
- Never edit the generated `app_localizations_*.dart` files. Edit the `.arb`
  source and run `make l10n`, then `make sort_arb_files`.
- **AI-assisted translation is fine**, provided you contribute from a real-name,
  established GitHub profile rather than a recently created account.
- If a longer string changes a layout, include a screenshot of the affected
  screen. Attach it to the PR — please do not commit images to this repository.

## Bug reports

Useful reports beat thorough ones. Include the platform and app version, what you
did, what you expected, and what happened instead. If it is reproducible, the
steps matter more than anything else.

There is no telemetry and no crash reporting, so nothing reaches me unless you
send it. Logs are local: *Settings → Advanced → Logging* controls what is
recorded, and the files stay on your device until you choose to share them.

## Security

Please do not open a public issue for a vulnerability. See
[SECURITY.md](SECURITY.md).

## Building it locally

Setup and day-to-day commands are in [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md),
and the manual's [Connect an AI provider](https://matthiasn.github.io/lotti/manual/development/ai-and-automation/provider-setup/)
covers configuring AI. Both exist so you can run and modify your own copy — not
as an on-ramp to a pull request.
