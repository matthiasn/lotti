---
name: review-comments
description: Fetch PR review comments, address each one in code, and post resolution replies
argument-hint: "[pr-number]"
---

# Review PR Comments

Fetch all review comments from a pull request, address each one (fix code, add
docs, or explain the rationale), and reply to each comment on GitHub with the
resolution.

## Steps

1. **Fetch comments** — use `gh api` to get all review comments:
   ```bash
   gh api repos/{owner}/{repo}/pulls/$ARGUMENTS/comments \
     --jq '.[] | {id, path, line, body, in_reply_to_id}'
   ```
   Filter to top-level comments only (`in_reply_to_id == null`) — those are the
   ones that need responses.

2. **Understand each comment** — read the referenced file and line to understand
   the concern. Group related comments if they touch the same issue.

3. **Address each comment** — make the appropriate code change (fix, refactor,
   add docs, add tests). If you disagree with a suggestion, prepare a clear
   rationale.

4. **Reply to each comment** — post a reply using:
   ```bash
   gh api repos/{owner}/{repo}/pulls/$ARGUMENTS/comments -X POST \
     -f body="<resolution>" \
     -F in_reply_to=<comment-id>
   ```
   Keep replies concise: state what was done (e.g., "Fixed. Replaced generic
   fallback with explicit throw.") or explain why it was left as-is.

5. **Close every codecov gap — target 100% patch coverage.** The Codecov bot
   posts a PR comment/check; treat its uncovered lines as review comments that
   MUST be resolved with tests. **Every line codecov marks uncovered has to be
   covered — no exceptions for "pre-existing" files.** If a file shows up in the
   PR diff with uncovered lines, cover them even if you didn't write them.

   a. **Find what's actually uncovered.** The bot summary only gives totals;
      pull the per-line data from the Codecov API and intersect it with the
      PR's added lines (this is exactly what `codecov/patch` scores):
      ```bash
      # Per-line diff coverage (head_cov == 0 → miss):
      curl -s "https://api.codecov.io/api/v2/github/{owner}/repos/{repo}/compare?pullid=$ARGUMENTS" \
        > /tmp/cc.json
      # Then: for each file with has_diff, list lines where
      #   coverage.head == 0 && is_diff, and intersect with the file's
      #   git-diff added-line numbers (git diff --unified=0 origin/main...HEAD).
      ```
      Codecov ignores are in `codecov.yml` (`*.g.dart`, `*.freezed.dart`,
      `l10n/*.dart` here) — skip those.

   b. **Codecov is often stale/partial — trust local coverage for new code.**
      Coverage is sharded; if any shard failed or the run is mid-flight, the
      bot shows a partial picture (e.g. "1% of diff") that inflates the miss
      list with trivial lines (`@override`, const ctors). Regenerate locally
      and intersect with the git-diff added lines for the authoritative set:
      ```bash
      fvm flutter test --coverage <the test dirs that exercise the diff>
      # parse coverage/lcov.info: DA:<line>,0 == uncovered
      ```
      Run enough test dirs that every diff file is genuinely exercised (a file
      covered only by tests you didn't run shows as a false miss).

   c. **Write real tests for each uncovered line** — mirror the sibling case
      already tested (e.g. a new `.map`/`switch` arm → copy the `aiConfig`
      case for `savedTaskFilter`; a debounce-cancel line → emit *two*
      notifications so the timer is non-null when cancelled). Extend
      parameterized `variantCases`/`variantsByBucket` tables rather than
      duplicating whole test bodies.

   d. **Uncoverable private-ctor lines** (`const FooKeys._();` in a static-only
      keys class) can't be hit and dart coverage ignores no inline comment —
      convert the class to `abstract final class FooKeys { ... }` so the
      constructor line disappears entirely.

   e. **Re-run coverage until the (added ∩ uncovered) set is empty**, then run
      the affected suites to confirm still-green.

6. **Verify** — run analyzer and affected tests to confirm all changes compile
   and pass.

## Guidelines

- Address ALL comments — do not skip any.
- Make real code fixes, not just reply text.
- Run the analyzer and formatter after all fixes.
- Run affected tests to verify fixes.
- Keep reply text concise and factual.
- If a comment is from a bot review (e.g., CodeRabbit, Gemini), still address
  valid points but use your judgement on noise.
- Coverage is not optional: every codecov-flagged line in the diff must end up
  covered (goal 100% patch), pre-existing or not. Prefer real behavioural tests;
  only restructure code (e.g. `abstract final class`) for genuinely
  uncoverable lines.
