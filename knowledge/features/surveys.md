---
type: Feature Module
title: Surveys
description: "A narrow runner for predefined questionnaires that scores answers into buckets and persists the result as a journal entry."
resource: ../../lib/features/surveys
tags: [surveys, questionnaires, scoring]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-26T04:15:00Z }
stale_after: 2027-03-08
sources:
  - id: src
    resource: ../../lib/features/surveys
    title: Surveys source
    last_modified: 2026-07-26
---

The surveys feature executes a small set of **predefined** questionnaires,
calculates score buckets from the submitted answers, and persists the result as a
survey journal entry.

**It is deliberately narrow.** It is not a survey-authoring system, and it does
not own charting or journal presentation.

At runtime it owns the survey definitions built with `research_package`, a thin
modal runner around the package's task widget, the scoring that turns raw answers
into buckets, and persistence as a `SurveyEntry`.

# Why scoring lives here

The raw answers alone are not useful to a chart or a summary — a score bucket is.
Computing it at submission time means the persisted entry is **self-describing**:
a dashboard chart or an AI summary reads a scored result without needing to know
the questionnaire's scoring rules, and a later change to those rules does not
retroactively rewrite history.

The definitions are code, not data, so a questionnaire cannot drift between
devices mid-submission.
