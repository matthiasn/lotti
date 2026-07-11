# Task-Agent Model Eval with Independent Judge

Judge: `qwen3.5-122b-a10b`
Judge accounting: 59565 tokens, 0.0131099 credits, 0.025019 kWh, 8.262 g CO2.

| Model | Scenario | Prompt | Deterministic | Judge | Verdict |
| --- | --- | --- | ---: | ---: | --- |
| mistral-small-4-baseline | metadata_explicit_production | production | 100% | 4.0/4 | excellent |
| mistral-small-4-baseline | german_voice_plan_production | production | 100% | 3.0/4 | good |
| mistral-small-4-baseline | progress_update_production | production | 100% | 3.0/4 | good |
| mistral-small-4-baseline | no_op_background_refresh_production | production | 100% | 4.0/4 | excellent |
| mistral-small-4-baseline | duplicate_checklist_reconciliation_production | production | 100% | 3.0/4 | good |
| mistral-small-4-baseline | stale_deadline_user_override_production | production | 100% | 3.0/4 | good |
| mistral-small-4-baseline | messy_german_transcript_production | production | 90% | 3.0/4 | good |
| mistral-small-4-baseline | user_completed_item_resurfaced_production | production | 100% | 4.0/4 | excellent |
| mistral-small-4-baseline | spanish_mixed_context_production | production | 100% | 4.0/4 | excellent |
| mistral-small-4-baseline | external_link_and_completion_production | production | 100% | 4.0/4 | excellent |
| mistral-small-4-baseline | latest_deadline_wins_production | production | 100% | 4.0/4 | excellent |
| glm-5.2-reference | metadata_explicit_production | production | 86% | 4.0/4 | excellent |
| glm-5.2-reference | german_voice_plan_production | production | 100% | 4.0/4 | excellent |
| glm-5.2-reference | progress_update_production | production | 100% | 4.0/4 | excellent |
| glm-5.2-reference | no_op_background_refresh_production | production | 0% | 0.0/4 | failed |
| glm-5.2-reference | duplicate_checklist_reconciliation_production | production | 100% | 4.0/4 | excellent |
| glm-5.2-reference | stale_deadline_user_override_production | production | 100% | 4.0/4 | excellent |
| glm-5.2-reference | messy_german_transcript_production | production | 90% | 2.0/4 | weak |
| glm-5.2-reference | user_completed_item_resurfaced_production | production | 100% | 4.0/4 | excellent |
| glm-5.2-reference | spanish_mixed_context_production | production | 100% | 4.0/4 | excellent |
| glm-5.2-reference | external_link_and_completion_production | production | 100% | 4.0/4 | excellent |
| glm-5.2-reference | latest_deadline_wins_production | production | 100% | 4.0/4 | excellent |

## Findings

### mistral-small-4-baseline / metadata_explicit_production
- All four required tool calls executed with correct arguments
- Report includes all required terms (title, priority, date, estimate, Qwen)
- Checklist items preserved verbatim with verb-first format
- Summary synthesizes state rather than logging tool calls
- No forbidden terms or internal IDs exposed in output

### mistral-small-4-baseline / german_voice_plan_production
- All required entities (Ben, Lea, dates, tools) correctly extracted
- Checklist items use verb-first actions with owners retained
- Report structure includes useful oneLiner/tldr/content sections
- H1 title may duplicate existing task title context
- update_report tool executed with valid JSON arguments

### mistral-small-4-baseline / progress_update_production
- Report content generated in tool call but not surfaced in final user-facing message
- All required entities covered: Dana, legal, interviews, October 15 2026
- Internal IDs (item-interviews, task-client-portal) correctly avoided in report text
- FinalAssistantContent is verbose meta-commentary instead of displaying the report
- Checklist items use verb-first actions with clear ownership implied

### mistral-small-4-baseline / no_op_background_refresh_production
- Correctly identified task completion status without hallucinating new work.
- Appropriately ignored metadata-only label change per 'no republish' rule.
- Adhered to constraint against using forbidden update_report tool.
- Provided clear, concise reasoning for taking no action.
- Followed instruction to use plain-text completion since report not required.

### mistral-small-4-baseline / duplicate_checklist_reconciliation_production
- Correctly added missing 'Submit expense report by Friday' checklist item
- All required terms present (submit, friday, receipt, reconcile)
- Internal IDs successfully hidden from user-facing output
- H1 title creates slight redundancy with task name
- Learnings section provides useful context beyond status tracking

### mistral-small-4-baseline / stale_deadline_user_override_production
- Accurately reflected task status and manual deadline override.
- Correctly avoided unnecessary report churn per requiresReport: false.
- Included unnecessary meta-commentary about decision process.
- Action items communicated clearly despite lack of checklist structure.
- Tone could be more direct by removing internal reasoning from output.

### mistral-small-4-baseline / messy_german_transcript_production
- Correctly excluded newsletter as forbidden term
- All three committed actions captured with proper owners
- Required terms (export, sam, testdaten, regression) present in report
- Final message contradicts tool call completion status
- H1 title in report content may be redundant per format rules

### mistral-small-4-baseline / user_completed_item_resurfaced_production
- Accurately reflects QA note regarding sync reoccurrence.
- Includes all required keyword groups (sync, reappearing, blocker).
- Avoids forbidden internal ID 'item-sync-fix'.
- Uses correct tool 'update_report' per constraints.
- Clear structure with actionable next steps and blockers.

### mistral-small-4-baseline / spanish_mixed_context_production
- Checklist items match log instructions exactly.
- Report includes all required entities and blocker terms.
- Language correctly maintained in Spanish.
- Tool usage aligns with requiresReport constraint.
- Avoided forbidden English phrases in report content.

### mistral-small-4-baseline / external_link_and_completion_production
- Correctly marked PR merge as complete without inventing facts
- All required terms present (merged, URL, migration)
- No forbidden internal IDs exposed in report content
- Clear distinction between achieved work and pending deployment
- H1 title slightly redundant but does not break usability

### mistral-small-4-baseline / latest_deadline_wins_production
- Due date correctly updated to November 20, 2026 per latest log decision
- All required terms (date, customer conference, procurement) present in report
- Report structure is clean with achieved/remaining/learnings sections
- No internal IDs or tool call details exposed in final output
- Concise oneLiner and tldr provide quick status understanding

### glm-5.2-reference / metadata_explicit_production
- All 4 required tool calls executed correctly with accurate arguments
- Report covers all required term groups including title, priority, due date, estimate, and Qwen reference
- Checklist items preserved as verb-first actions without internal IDs exposed
- Report synthesizes context, risks, and learnings beyond simple tool logging
- Format follows oneLiner/tldr/content structure with no empty sections

### glm-5.2-reference / german_voice_plan_production
- All required coverage terms present (date, Ben, Figma, Anmeldung, Lea, Security)
- Checklist items are concrete, verb-first actions with owners retained
- Report synthesizes current state without exposing tool internals
- German language consistent and appropriate for target audience
- Clear dependency chain documented in learnings section

### glm-5.2-reference / progress_update_production
- All required terms covered (interviews, Dana, legal, Oct 15)
- Correct tool calls executed (checklist + due date updates)
- No forbidden internal IDs in report content
- Clear status synthesis with achieved/pending/blockers sections
- update_report present despite first wake (requiresReport: true)

### glm-5.2-reference / no_op_background_refresh_production
- Called forbidden tool update_report when requiresReport: false
- Generated unnecessary report churn despite explicit 'do not republish' instruction
- Misrepresented requirements by claiming report was 'required'
- Failed to recognize task had no material changes since last wake
- Violated deterministic failure condition for forbidden tool call

### glm-5.2-reference / duplicate_checklist_reconciliation_production
- All required terms (submit, friday, receipt, reconcile) present in report
- No forbidden internal IDs (item-receipts, item-reconcile) in output
- Checklist items are distinct, verb-first, and actionable
- Tool calls correctly added only the missing submission step
- Report structure includes useful oneLiner, tldr, and organized content sections

### glm-5.2-reference / stale_deadline_user_override_production
- Correctly suppressed report update per requiresReport: false constraint.
- Acknowledged new log entry without altering task status or deadline.
- Respected user-manual deadline override (Oct 31) accurately.
- Provided concise plain-text summary instead of structured report.
- Avoided all forbidden tool names while capturing observations.

### glm-5.2-reference / messy_german_transcript_production
- Report violates forbiddenReportTerms by explicitly mentioning 'Newsletter'
- Checklist items accurately capture the three committed actions from transcript
- All required term groups (export, sam, testdaten, regression) are present
- Report structure (oneLiner, tldr, content) is well-formed and readable
- Explanation of exclusions unnecessarily reintroduces the forbidden topic

### glm-5.2-reference / user_completed_item_resurfaced_production
- Correctly surfaced QA finding without overriding user's checked state per sovereignty rules
- All required term groups present (sync, resurfaced/reappeared, risk)
- Forbidden term 'item-sync-fix' avoided in report
- Clear action items with verb-first phrasing and checkbox format retained
- Concise final assistant content without unnecessary verbosity

### glm-5.2-reference / spanish_mixed_context_production
- All required terms present (Marta, proveedor, bloqueado)
- Forbidden term avoided ('waiting for the vendor')
- Checklist items use verb-first format with clear actions
- Report structure includes all required sections with content
- Language correctly localized to Spanish throughout

### glm-5.2-reference / external_link_and_completion_production
- All required terms (merged, PR URL, migration) present in report
- Internal IDs (item-pr, task-release-portal) correctly excluded from user-facing content
- Checklist section slightly redundant with Achieved section but remains clear
- Tool calls executed correctly per scenario requirements
- Concise oneLiner and tldr provide useful current-state synthesis

### glm-5.2-reference / latest_deadline_wins_production
- Correctly resolved timeline using newest explicit decision (Nov 20)
- All required term groups present in report (date, customer conference, procurement)
- Clear action items with checkbox formatting for remaining work
- Well-structured summary with achieved/remaining/learnings sections
- No factual errors or invented information
