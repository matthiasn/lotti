---
type: Convention
title: Code style and analysis
description: "Very Good Analysis with a small override set, a zero-warning gate, generated code that is never hand-edited, and design tokens instead of literals."
resource: ../../analysis_options.yaml
tags: [convention, style, analyzer, codegen, tokens]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-26T04:30:00Z }
stale_after: 2027-01-18
sources:
  - id: analysis
    resource: ../../analysis_options.yaml
    title: Analyzer configuration
    last_modified: 2026-06-20
  - id: agents-md
    resource: ../../AGENTS.md
    title: Repository guidelines
    last_modified: 2026-07-26
  - id: build-yaml
    resource: ../../build.yaml
    title: Code generation config
    last_modified: 2026-07-22
---

# Analyzer: zero warnings, zero infos

The project uses **Very Good Analysis** with a small, deliberate override set
(`public_member_api_docs`, `lines_longer_than_80_chars`, `flutter_style_todos`,
`document_ignores`, `avoid_catches_without_on_clauses`, `discarded_futures`,
`require_trailing_commas`, `avoid_types_on_closure_parameters` off) plus
`strict-raw-types: true`.

**Before a PR the analyzer must report zero warnings and zero infos.**

- In **tests**, a line-scoped `// ignore:` is acceptable for clarity.
- In **production code**, fix the root cause rather than ignoring.

Generated files (`*.g.dart`, `*.freezed.dart`) and the vendored `third_party/`
tree are excluded from analysis.

# Naming and formatting

Files `lower_snake_case.dart`; types `PascalCase`; members `lowerCamelCase`.
Two-space indent, prefer `const` and `final`. Run `fvm dart format .` before
committing.

# Generated code is checked in and never hand-edited

`*.g.dart`, `*.freezed.dart`, `objectbox.g.dart` and the generated design tokens
are regenerated with `make build_runner` (or the design-system import).

**One trap is worth memorizing: never pair `--build-filter` with
`--delete-conflicting-outputs`.** The combination deletes generated files
*outside* the filter and does not regenerate them, because the filter excludes
them from the build that would have rewritten them.

The build itself **succeeds and reports nothing**, so the only signal is `git
status` showing generated files as deleted — these files are tracked, not
ignored. Read it before committing, or the deletions travel with the change and
surface later as an unrelated build failure.

# Design tokens are mandatory

Colors, spacing, radii, typography and elevation come from the exported
design-system tokens or existing design-system abstractions.

**Never hardcode spacing or font styles** — no raw numbers in `EdgeInsets` or
`SizedBox`, no local `const double` spacing constants, no bare `fontSize` or
`fontWeight`. Use `tokens.spacing.stepN` (or `cardPadding`, `cardItemSpacing`,
`sectionGap`) and `tokens.typography.styles.*`.

**If no suitable token exists, stop and ask before introducing one.** The fix
belongs upstream at the token source or the design-system seam, not at the call
site. See [the design system](../features/design_system/).

# Two more standing rules

- **No dependencies from new code to old** when two versions of a feature
  coexist, since the point is to delete the old one.
- **No hoarded code.** This is an application, not a library — there are no
  unknown callers to keep dead code alive for.
