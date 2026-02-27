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

5. **Verify** — run analyzer and affected tests to confirm all changes compile
   and pass.

## Guidelines

- Address ALL comments — do not skip any.
- Make real code fixes, not just reply text.
- Run the analyzer and formatter after all fixes.
- Run affected tests to verify fixes.
- Keep reply text concise and factual.
- If a comment is from a bot review (e.g., CodeRabbit, Gemini), still address
  valid points but use your judgement on noise.
