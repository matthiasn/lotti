# ADR 0165: Pull Requests Are Found by a Call of Their Own

- Status: Accepted
- Date: 2026-11-12
- Concepts: [front agent](../../knowledge/features/front_agent.md), [GitHub pull requests](../../knowledge/features/github.md)

## Context

A user asks the companion *"what was the task where I worked on the A2UI
notation in the past two weeks?"*. The answer is in the pull requests
linked to their tasks: a title, the one-liner of its summary, the task
that holds it.

`summarize_pull_requests` already reads a window of pull requests, but for
counting: it lists at most 30 by title and puts them into her
conversation. The owner ships around ten pull requests a day, so two weeks
is more than a hundred. Listing them all, with their summaries, would put
thousands of tokens of mostly unrelated pull requests into the turn, and
the 30-line cap already cuts the one asked about.

Two ways to narrow them were weighed:

- **Matching on the device** — words or the embedding index. Free and
  fast, but a topic rarely shares words with a title ("A2UI notation" and
  *"her answer is the message she writes"* share none), and the summaries
  that would bridge them are what a model reads best.
- **A model call apart from her conversation.** It reads every candidate
  — key, title, one-liner, the task's title — and returns the few that are
  about the topic. Its prompt is thrown away; only what it keeps enters her
  conversation.

## Decision

1. **`find_pull_requests(topic, window)` filters in a call of its own.**
   The candidates of the window go to a separate conversation on her model,
   with its own system message, no tools and a one-call budget. It answers
   with keys; a key it makes up is dropped. At most five come back.
2. **She sees only what it kept**, each with its task and summary, and the
   holding tasks become rows her words may link.
3. **The filter always runs when there are candidates.** Skipping it for a
   handful would hand her pull requests that are not about the topic, which
   would then be drawn.
4. **A failed filter call fails the lookup, not the turn.** She is told the
   search failed and says so.
5. **Cards name a pull request by key and its task, and read both live**
   (ADR 0163, point 2). They are the task page's own rows.
6. **Follow-ups read what is stored.** The pull requests a conversation
   showed are listed to her as `<conversation_pull_requests>`, and
   `read_pull_requests` renders one in full from the stored snapshot.
   GitHub is not asked at question time.

## Consequences

- A pull request question costs one more provider call, billed to her
  turn, and about a second of latency.
- The filter sends pull request titles and summaries to the provider the
  user picked for her, the same one her conversation goes to. Nothing else
  leaves the device.
- A month of pull requests is one prompt. Past 300 candidates the oldest
  are not searched (`frontPullRequestFilterMaxCandidates`).
- The app stores no diff, file list or reviewer names, so a follow-up asking
  for those is answered with what is stored, and the card's menu opens the
  pull request on GitHub.
