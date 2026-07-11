# Local Task-Agent Inference Eval

Provider: `Task Agent Eval (genericOpenAi)` (genericOpenAi) at `https://api.melious.ai/v1`

| Profile | Model | Scenario | Prompt | Pass | Quality | Retry | Latency | Tool calls | Failure |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: | --- | --- |
| mistral-small-4-baseline | `mistral-small-4-119b-instruct` | metadata_explicit_conciseReport | conciseReport | yes | 100% | no | 3661 ms | set_task_title, update_task_priority, update_task_due_date, update_task_estimate, update_report | none |
| mistral-small-4-baseline | `mistral-small-4-119b-instruct` | german_voice_plan_conciseReport | conciseReport | yes | 100% | no | 2939 ms | add_multiple_checklist_items, update_report | none |
| mistral-small-4-baseline | `mistral-small-4-119b-instruct` | progress_update_conciseReport | conciseReport | yes | 100% | no | 2920 ms | update_checklist_items, update_task_due_date, update_report | none |
| mistral-small-4-baseline | `mistral-small-4-119b-instruct` | no_op_background_refresh_conciseReport | conciseReport | yes | 100% | no | 846 ms | - | none |
| mistral-small-4-baseline | `mistral-small-4-119b-instruct` | duplicate_checklist_reconciliation_conciseReport | conciseReport | no | 100% | no | 1928 ms | update_report | missingExpectedToolCall |
| mistral-small-4-baseline | `mistral-small-4-119b-instruct` | stale_deadline_user_override_conciseReport | conciseReport | yes | 100% | no | 1366 ms | - | none |
| mistral-small-4-baseline | `mistral-small-4-119b-instruct` | messy_german_transcript_conciseReport | conciseReport | no | 60% | no | 1992 ms | update_report | missingExpectedToolCall |
| mistral-small-4-baseline | `mistral-small-4-119b-instruct` | user_completed_item_resurfaced_conciseReport | conciseReport | no | 80% | no | 2723 ms | update_checklist_items, update_report | forbiddenToolCall |
| mistral-small-4-baseline | `mistral-small-4-119b-instruct` | spanish_mixed_context_conciseReport | conciseReport | yes | 100% | no | 2959 ms | add_multiple_checklist_items, update_report | none |
| mistral-small-4-baseline | `mistral-small-4-119b-instruct` | external_link_and_completion_conciseReport | conciseReport | yes | 100% | no | 2250 ms | update_checklist_items, update_report | none |
| mistral-small-4-baseline | `mistral-small-4-119b-instruct` | latest_deadline_wins_conciseReport | conciseReport | yes | 100% | no | 2998 ms | update_task_due_date, update_report | none |

## Case Details

### mistral-small-4-baseline / metadata_explicit_conciseReport

Deterministic quality: 7/7.

Final assistant content:

```text
I'll apply the user's requested changes: title, priority P1, due date July 4 2026, and estimate 2.5 hours (150 minutes).
```

`set_task_title`

```json
{"title": "Validate local Gemma fallback"}
```

`update_task_priority`

```json
{"priority": "P1"}
```

`update_task_due_date`

```json
{"dueDate": "2026-07-04"}
```

`update_task_estimate`

```json
{"minutes": 150}
```

`update_report`

```json
{"oneLiner": "Gemma local eval task configured with P1 priority and July 4 deadline", "tldr": "Task metadata set. Ready to run meaningful local app eval comparing Gemma to Qwen baseline.", "content": "## Progress\n- Task titled \"Validate local Gemma fallback\"\n- Priority set to P1\n- Due date set to 2026-07-04\n- Estimate set to 150 minutes (2.5 hours)\n\n## Next actions\n- Run a meaningful local app eval (checklist item 1)\n- Compare Gemma against Qwen on task-agent behavior (checklist item 2)\n\n## Blockers\nNone\n\n## Decisions\n- User requested title, P1 priority, July 4 2026 due date, and 2.5 hour estimate\n- Focus on runtime behavior affecting Lotti task-agent workflow, not generic benchmark scores"}
```

### mistral-small-4-baseline / german_voice_plan_conciseReport

Deterministic quality: 11/11.

Final assistant content:

```text
Ich erstelle die konkreten Checklisteneinträge basierend auf der Sprachnotiz vom 2026-07-10:
```

`add_multiple_checklist_items`

```json
{"items": [{"title": "API-Umfang mit Ben klären", "isChecked": false}, {"title": "Figma-Prototyp fertig machen", "isChecked": false}, {"title": "Anmeldung implementieren", "isChecked": false}, {"title": "Security-Review von Lea einholen", "isChecked": false}]}
```

`update_report`

```json
{"oneLiner": "Kundenportal Beta: API-Scope, Figma, Login und Security-Review geplant", "tldr": "4 neue Checklisteneinträge erstellt. Nächster Schritt: API-Umfang mit Ben klären.", "content": "## Fortschritt\n\n- 4 konkrete Checklisteneinträge basierend auf Sprachnotiz vom 2026-07-10 erstellt\n\n## Nächste Schritte\n\n1. API-Umfang mit Ben klären\n2. Figma-Prototyp fertig machen\n3. Anmeldung implementieren\n4. Security-Review von Lea einholen\n\n## Entscheidungen\n\n- Zieltermin: 30. September 2026\n- Status: IN PROGRESS\n- Priorität: P1"}
```

### mistral-small-4-baseline / progress_update_conciseReport

Deterministic quality: 7/7.

Final assistant content:

```text
I'll apply the explicit changes from the user's log: check off the customer interviews item and update the due date to October 15, 2026.
```

`update_checklist_items`

```json
{"items": [{"id": "item-interviews", "isChecked": true}]}
```

`update_task_due_date`

```json
{"dueDate": "2026-10-15"}
```

`update_report`

```json
{"oneLiner": "Customer portal launch in progress, interviews complete, legal review blocked", "tldr": "Five customer interviews completed. Legal review blocked pending Dana's retention clause confirmation. Launch deadline moved to 2026-10-15.", "content": "## Progress\n- Completed five customer interviews\n\n## Next actions\n- Await Dana's confirmation on retention clause to unblock legal review\n- Complete legal review once unblocked\n\n## Blockers\n- Legal review blocked: waiting for Dana to confirm retention clause\n\n## Decisions\n- Launch deadline updated to 2026-10-15"}
```

### mistral-small-4-baseline / no_op_background_refresh_conciseReport

Deterministic quality: 1/1.

Final assistant content:

```text
The task is complete (status: DONE), checklist items are checked, and the report already reflects this. The only change noted is a label update (label-tax), which doesn't require any action or report update.

No report-worthy changes occurred.
```

### mistral-small-4-baseline / duplicate_checklist_reconciliation_conciseReport

Deterministic quality: 8/8.

Final assistant content:

```text
I see the task already has two checklist items that match what the user requested:
- "Email the Q2 receipts to Finance"
- "Reconcile the card transactions"

The user's request was to ensure the checklist covers these three things (emailing receipts, reconciling transactions, and submitting the report). The first two are already present. The third item (submitting the expense report) is the actual work to be done, not a checklist item - it's the task itself.

No new checklist items are needed. The existing items are sufficient.

**Report:**
```

`update_report`

```json
{"oneLiner": "Q2 expense report in progress with two checklist items pending", "tldr": "Task in progress. Two checklist items remain: email receipts and reconcile card transactions.", "content": "## Progress\n- Task created with checklist covering Q2 expense submission requirements\n\n## Next actions\n- Email the Q2 receipts to Finance\n- Reconcile the card transactions\n- Submit the expense report by Friday\n\n## Decisions\n- Checklist items preserved as requested; no duplicates added"}
```

### mistral-small-4-baseline / stale_deadline_user_override_conciseReport

Deterministic quality: 2/2.

Final assistant content:

```text
The task context shows the due date is already set to 2026-10-31 as the user manually specified, and the status is IN PROGRESS. The only new information is the note about the app icon looking good on the dark home screen, which is progress but doesn't require a status change or metadata update.

Since nothing report-worthy has changed (the user's manual deadline is respected, no new blockers, no checklist items completed), I'll finish with a brief note rather than republishing an unchanged report.

**No report update needed** — the task remains on track for October 31 with release QA pending. The app icon approval noted is progress but doesn't change the current state.
```

### mistral-small-4-baseline / messy_german_transcript_conciseReport

Deterministic quality: 6/10.

Final assistant content:

```text
Ich habe die Sprachnotiz transkribiert und die drei konkreten Aufgaben identifiziert:
1. CSV-Export reparieren
2. Sam nach anonymisierten Testdaten fragen
3. Regressionstest laufen lassen

Die Erwähnung von "Newsletter" ist eine zukünftige Idee, die der Nutzer explizit als "noch nicht aufnehmen" markiert hat, daher werde ich sie nicht in die Aufgaben einbeziehen.

Da dies der erste Wake ist und noch kein Report existiert, erstelle ich jetzt den initialen Report.
```

`update_report`

```json
{"oneLiner": "CSV-Export-Reparatur, Testdaten-Anfrage und Regressionstest geplant", "tldr": "Drei konkrete Aufgaben identifiziert: CSV-Export reparieren, Testdaten von Sam anfordern, Regressionstest ausführen.", "content": "## Nächste Schritte\n\n- CSV-Export reparieren\n- Sam nach anonymisierten Testdaten fragen\n- Regressionstest nach Testdaten erhalten ausführen\n\n## Status\n\n- Status: IN PROGRESS\n- Sprache: Deutsch"}
```

### mistral-small-4-baseline / user_completed_item_resurfaced_conciseReport

Deterministic quality: 4/5.

Final assistant content:

```text
The QA note indicates the duplicate sync issue has reappeared, so the "Fix duplicate sync events" item should be unchecked to reflect the current state. I'll update the checklist item and then publish the report.
```

`update_checklist_items`

```json
{"items": [{"id": "item-sync-fix", "isChecked": false, "reason": "QA note at 2026-07-10T11:20:00Z reports duplicate sync events reappeared after reconnecting two devices."}]}
```

`update_report`

```json
{"oneLiner": "Duplicate sync fix reverted; investigation needed", "tldr": "Duplicate sync events reappeared after device reconnection; root cause investigation required.", "content": "## Progress\n- Fixed duplicate sync events (reverted due to recurrence)\n\n## Next actions\n- Investigate root cause of duplicate sync events reappearing after device reconnection\n\n## Blockers\n- Duplicate sync events reappeared after reconnecting two devices (QA note at 2026-07-10T11:20:00Z); no root cause identified yet"}
```

### mistral-small-4-baseline / spanish_mixed_context_conciseReport

Deterministic quality: 6/6.

Final assistant content:

```text
Voy a crear los dos pasos de la lista de verificación mencionados en el log y luego publicar el informe inicial.
```

`add_multiple_checklist_items`

```json
{"items": [{"title": "Llamar al proveedor para pedir las credenciales", "isChecked": false}, {"title": "Confirmar con Marta la fecha de activación", "isChecked": false}]}
```

`update_report`

```json
{"oneLiner": "Esperando credenciales del proveedor para activar facturación electrónica", "tldr": "Bloqueado por falta de credenciales del proveedor. Se añadieron dos pasos pendientes: contactar al proveedor y confirmar fecha con Marta.", "content": "## Progreso\n- Se añadieron dos pasos a la lista de verificación para desbloquear la activación:\n  - Llamar al proveedor para pedir las credenciales\n  - Confirmar con Marta la fecha de activación\n\n## Acciones siguientes\n1. Contactar al proveedor externo para obtener las credenciales necesarias\n2. Coordinar con Marta la fecha de activación una vez recibidas las credenciales\n\n## Bloqueadores\n- El proveedor externo no ha enviado las credenciales requeridas para la activación de la facturación electrónica\n\n## Decisiones\n- La tarea permanece en estado \"IN PROGRESS\" mientras se resuelve el bloqueo con el proveedor"}
```

### mistral-small-4-baseline / external_link_and_completion_conciseReport

Deterministic quality: 5/5.

Final assistant content:

```text
I'll check off the merge item since the PR was merged, and update the report to reflect the current state.
```

`update_checklist_items`

```json
{"items": [{"id": "item-pr", "isChecked": true}]}
```

`update_report`

```json
{"oneLiner": "PR merged, deployment pending for tomorrow's maintenance window", "tldr": "PR #482 merged successfully. Deployment scheduled for tomorrow's maintenance window.", "content": "## Progress\n- PR #482 merged: https://github.com/acme/portal/pull/482\n\n## Next actions\n- Deploy the migration during tomorrow's maintenance window\n\n## Blockers\n- Deployment pending until maintenance window tomorrow"}
```

### mistral-small-4-baseline / latest_deadline_wins_conciseReport

Deterministic quality: 3/3.

`update_task_due_date`

```json
{"dueDate": "2026-11-20"}
```

`update_report`

```json
{"oneLiner": "Enterprise demo rescheduled to November 20, 2026; script pending.", "tldr": "Due date updated to November 20, 2026 for confirmed customer conference. Demo script remains the only outstanding item.", "content": "## Progress\n- Demo dataset prepared and ready.\n- Customer conference slot confirmed by procurement.\n\n## Next actions\n- Finalize demo script.\n\n## Decisions\n- Task rescheduled to November 20, 2026 for customer conference demo."}
```

## Failures
- `mistral-small-4-baseline` / `duplicate_checklist_reconciliation_conciseReport`: missingExpectedToolCall
- `mistral-small-4-baseline` / `messy_german_transcript_conciseReport`: missingExpectedToolCall
- `mistral-small-4-baseline` / `user_completed_item_resurfaced_conciseReport`: forbiddenToolCall
