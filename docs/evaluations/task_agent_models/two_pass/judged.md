# Task-Agent Model Eval with Independent Judge

Judge: `qwen3.5-122b-a10b`
Judge accounting: 29660 tokens, 0.0058286 credits, 0.009219 kWh, 3.052 g CO2.

| Model | Scenario | Prompt | Deterministic | Judge | Verdict |
| --- | --- | --- | ---: | ---: | --- |
| mistral-small-4-baseline | metadata_explicit_production | production | 100% | 4.0/4 | excellent |
| mistral-small-4-baseline | german_voice_plan_production | production | 91% | 3.0/4 | good |
| mistral-small-4-baseline | progress_update_production | production | 86% | 2.6/4 | good |
| mistral-small-4-baseline | no_op_background_refresh_production | production | 100% | 4.0/4 | excellent |
| mistral-small-4-baseline | duplicate_checklist_reconciliation_production | production | 100% | 4.0/4 | excellent |
| mistral-small-4-baseline | stale_deadline_user_override_production | production | 100% | 4.0/4 | excellent |
| mistral-small-4-baseline | messy_german_transcript_production | production | 100% | 4.0/4 | excellent |
| mistral-small-4-baseline | user_completed_item_resurfaced_production | production | 80% | 3.0/4 | weak |
| mistral-small-4-baseline | spanish_mixed_context_production | production | 100% | 4.0/4 | excellent |
| mistral-small-4-baseline | external_link_and_completion_production | production | 100% | 4.0/4 | excellent |
| mistral-small-4-baseline | latest_deadline_wins_production | production | 100% | 3.0/4 | good |

## Findings

### mistral-small-4-baseline / metadata_explicit_production
- All four required tool calls executed correctly with proper arguments
- Product report contains all required term groups without forbidden terms
- No internal IDs (check-1, check-2) leaked into user-facing content
- Report synthesizes current state rather than logging tool calls
- Checklist items are verb-first, distinct actions with clear owners retained

### mistral-small-4-baseline / german_voice_plan_production
- Missing required date reference (30. September/due date) in product report
- All four checklist items correctly extracted from voice note with proper owners
- Report structure is clean with Achieved/What's Left/Learnings sections
- No forbidden terms present; all required people (Ben, Lea) mentioned
- Technical term 'auth' missing though 'Anmeldung' provides semantic coverage

### mistral-small-4-baseline / progress_update_production
- Due date (Oct 15, 2026) applied via tool but missing from report content despite being a required term
- Empty 'Links' section violates no-empty-sections requirement
- Learnings section redundantly repeats the legal blocker already stated in 'What is left to do'
- Core status updates (interviews complete, legal blocked by Dana) accurately captured
- Report uses user-facing language without exposing internal IDs

### mistral-small-4-baseline / no_op_background_refresh_production
- Accurately assessed task completion status against context.
- Correctly prioritized task state over sync signal for actionability.
- Adhered to constraints forbidding report updates.
- Delivered concise plain-text explanation instead of unnecessary report structure.
- Avoided exposure of internal task identifiers in final output.

### mistral-small-4-baseline / duplicate_checklist_reconciliation_production
- Correctly added only the missing Friday submission item without duplicating existing checklist entries
- Report contains all required term groups (submit, friday, receipt, reconcile) while avoiding forbidden internal IDs
- Clear distinction between achieved work and remaining tasks in structured format
- Concise oneLiner and tldr effectively summarize task status without tool log verbosity
- Two update_report calls reflect normal production workflow (main + reportPass phases)

### mistral-small-4-baseline / stale_deadline_user_override_production
- Correctly suppressed report generation per requiresReport: false
- Accurately reflected manual deadline override without modification
- Avoided forbidden tool calls and unnecessary churn
- Provided clear rationale for no action in user-facing language
- Concise plain-text completion aligned with scenario constraints

### mistral-small-4-baseline / messy_german_transcript_production
- All three committed actions correctly extracted from transcript without speculation
- Newsletter explicitly excluded as instructed (forbidden term not in report)
- Required terms (export, sam, testdaten, regression) all present in report
- Checklist items are verb-first, concrete, and retain owner references
- Empty 'Links' section slightly violates no-empty-sections requirement

### mistral-small-4-baseline / user_completed_item_resurfaced_production
- Missing required 'blocked/blocker/risk' terminology in report
- Accurately surfaces QA note about reappeared sync issue
- Checklist items are concrete and action-oriented
- Report structure follows expected format well
- 'Achieved' section may be premature given issue resurfaced

### mistral-small-4-baseline / spanish_mixed_context_production
- Checklist items correctly implement both requested actions from the log
- Report written entirely in Spanish as required by languageCode
- All required terms present: Marta, proveedor, bloqueado, pendiente
- Forbidden term 'waiting for the vendor' not used in report
- Clear structure with oneLiner, tldr, and organized content sections

### mistral-small-4-baseline / external_link_and_completion_production
- All required terms present (merged, PR URL, migration)
- No forbidden internal IDs exposed in product report
- Checklist item correctly updated based on log evidence
- Clear distinction between achieved and pending work
- Deployment blocker and timing clearly communicated

### mistral-small-4-baseline / latest_deadline_wins_production
- Due date correctly updated to November 20, 2026 per latest log decision
- All required terms present: November 20, customer conference, procurement
- Empty 'Links' section violates no-empty-sections format requirement
- Remaining action lacks explicit owner assignment
- Clear structure with achieved/left/learnings sections provides good synthesis
