# Local Task-Agent Inference Eval

Provider: `Task Agent Eval (genericOpenAi)` (genericOpenAi) at `https://api.melious.ai/v1`

| Profile | Model | Scenario | Prompt | Pass | Quality | Retry | Latency | Tool calls | Failure |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: | --- | --- |
| mistral-small-4-baseline | `mistral-small-4-119b-instruct` | metadata_explicit_production | production | no | 100% | no | 4364 ms | set_task_title, update_task_priority, update_task_due_date, update_task_estimate, update_report | inferenceFailed |
| mistral-small-4-baseline | `mistral-small-4-119b-instruct` | german_voice_plan_production | production | no | 91% | yes | 4337 ms | add_multiple_checklist_items, update_report, update_report | missingRequiredContent |
| mistral-small-4-baseline | `mistral-small-4-119b-instruct` | progress_update_production | production | yes | 100% | yes | 4573 ms | update_checklist_items, update_task_due_date, update_report, update_report | none |
| mistral-small-4-baseline | `mistral-small-4-119b-instruct` | no_op_background_refresh_production | production | yes | 100% | no | 3416 ms | - | none |
| mistral-small-4-baseline | `mistral-small-4-119b-instruct` | duplicate_checklist_reconciliation_production | production | yes | 100% | yes | 3905 ms | add_multiple_checklist_items, update_report, update_report | none |
| mistral-small-4-baseline | `mistral-small-4-119b-instruct` | stale_deadline_user_override_production | production | yes | 100% | no | 1008 ms | - | none |
| mistral-small-4-baseline | `mistral-small-4-119b-instruct` | messy_german_transcript_production | production | yes | 100% | yes | 4510 ms | add_multiple_checklist_items, update_report, update_report | none |
| mistral-small-4-baseline | `mistral-small-4-119b-instruct` | user_completed_item_resurfaced_production | production | no | 80% | yes | 3563 ms | record_observations, update_report, update_report | missingRequiredContent |
| mistral-small-4-baseline | `mistral-small-4-119b-instruct` | spanish_mixed_context_production | production | yes | 100% | yes | 4753 ms | add_multiple_checklist_items, update_report, update_report | none |
| mistral-small-4-baseline | `mistral-small-4-119b-instruct` | external_link_and_completion_production | production | yes | 100% | yes | 5243 ms | update_checklist_items, update_report, update_report | none |
| mistral-small-4-baseline | `mistral-small-4-119b-instruct` | latest_deadline_wins_production | production | yes | 100% | yes | 5626 ms | update_task_due_date, update_report, update_report | none |

## Case Details

### mistral-small-4-baseline / metadata_explicit_production

Deterministic quality: 7/7.

Final assistant content:

```text
Inference failed with exception: Invalid argument(s): Conversation bb1059cf-e0fe-4bf2-825d-18189b3f1da9 not found
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
{"oneLiner": "Task configured: title, P1 priority, due July 4, 150 min estimate set", "tldr": "Task metadata configured. Ready for local Gemma evaluation. 🧪", "content": "## ✅ Achieved\n- Set task title: \"Validate local Gemma fallback\"\n- Set priority to P1\n- Set due date: July 4, 2026\n- Set estimate: 150 minutes (2.5 hours)\n\n## 📌 What is left to do\n- [ ] Run a meaningful local app eval\n- [ ] Compare Gemma against Qwen on task-agent behavior\n\n## 💡 Learnings\nUser is skeptical of shallow tool-call smoke reports and wants a real app-shaped local eval. This aligns with the project focus on runtime behavior that affects the Lotti task-agent workflow, not generic benchmark scores.\n\n## 🔗 Links\n- [Qwen 3.6 local baseline](/tasks/task-qwen-baseline)"}
```

### mistral-small-4-baseline / german_voice_plan_production

Deterministic quality: 10/11.

Final assistant content:

```text
Ich erstelle die konkreten Checklisteneinträge basierend auf der Sprachnotiz vom 2026-07-10.
```

`add_multiple_checklist_items`

```json
{"items": [{"title": "API-Umfang mit Ben klären", "isChecked": false}, {"title": "Figma-Prototyp fertig machen", "isChecked": false}, {"title": "Anmeldung implementieren", "isChecked": false}, {"title": "Security-Review von Lea einholen", "isChecked": false}]}
```

`update_report`

```json
{"oneLiner": "Checkliste erstellt, Beta-Vorbereitung läuft", "tldr": "Checkliste mit 4 Hauptaufgaben erstellt. Beta-Vorbereitung läuft. 🚀", "content": "## ✅ Achieved\n\n- Checkliste mit 4 konkreten Aufgaben erstellt\n\n## 📌 Was noch zu tun bleibt\n\n- [ ] API-Umfang mit Ben klären\n- [ ] Figma-Prototyp fertig machen\n- [ ] Anmeldung implementieren\n- [ ] Security-Review von Lea einholen\n\n## 💡 Learnings\n\nDie Beta-Vorbereitung wurde in 4 klare Schritte unterteilt, die sequentiell abgearbeitet werden sollen.\n"}
```

`update_report`

```json
{
  "oneLiner": "Checkliste erstellt, API-Klärung als nächster Schritt",
  "tldr": "Die Beta-Vorbereitung ist gestartet. Die Checkliste mit 4 Aufgaben wurde erstellt. 🚀",
  "content": "## ✅ Achieved\n\n- Checkliste mit 4 konkreten Aufgaben erstellt\n\n## 📌 Was noch zu tun bleibt\n\n- [ ] API-Umfang mit Ben klären\n- [ ] Figma-Prototyp fertig machen\n- [ ] Anmeldung implementieren\n- [ ] Security-Review von Lea einholen\n\n## 💡 Learnings\n\nDie Beta-Vorbereitung wurde in 4 klare, sequenzielle Schritte unterteilt. Der erste Schritt ist die Klärung des API-Umfangs mit Ben."
}
```

### mistral-small-4-baseline / progress_update_production

Deterministic quality: 7/7.

Final assistant content:

```text
I'll analyze the task context and apply the requested changes:

1. Check off the "Interview five customers" item (all five interviews are complete)
2. Update the due date to October 15, 2026
3. Report the legal review blocker regarding Dana's retention clause confirmation

Let me make these updates:
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
{"oneLiner": "Customer interviews complete, legal review blocked on retention clause", "tldr": "Customer interviews done, awaiting legal review completion 📋⏸️", "content": "## ✅ Achieved\n- Completed all five customer interviews\n\n## 📌 What is left to do\n- [ ] Complete legal review (blocked: Dana needs to confirm retention clause)\n\n## ⚠️ Blockers\n- Legal review is blocked while Dana confirms the retention clause\n\n## 📊 Timeline Update\n- Due date moved from September 30, 2026 to October 15, 2026\n"}
```

`update_report`

```json
{
  "oneLiner": "Customer interviews complete, legal review blocked on retention clause",
  "tldr": "Interviews done, awaiting Dana's retention clause confirmation for legal review 📋⏸️",
  "content": "## ✅ Achieved\n- Completed all five customer interviews\n\n## 📌 What is left to do\n- [ ] Complete legal review (blocked: Dana needs to confirm retention clause)\n\n## ⚠️ Blockers\n- Legal review is blocked while Dana confirms the retention clause\n\n## 📊 Timeline Update\n- Due date moved from September 30, 2026 to October 15, 2026\n"
}
```

### mistral-small-4-baseline / no_op_background_refresh_production

Deterministic quality: 1/1.

Final assistant content:

```text
I noticed a label change (label-tax) was reported by the sync engine, but the task context shows no labels are currently assigned. This suggests the label may have been added or removed externally. Since the task is already DONE with all checklist items checked and the log confirms completion, no further action is needed on the task itself. The label change is informational and doesn't require any tool calls or report updates.
```

### mistral-small-4-baseline / duplicate_checklist_reconciliation_production

Deterministic quality: 8/8.

Final assistant content:

```text
I'll analyze the task context and add the missing checklist item for submitting the expense report by Friday, then publish the initial report.
```

`add_multiple_checklist_items`

```json
{"items": [{"title": "Submit the expense report by Friday", "isChecked": false}]}
```

`update_report`

```json
{"oneLiner": "Adding final checklist item for Friday submission deadline", "tldr": "Q2 expense report task initialized with 3 checklist items. Ready to begin work. 📋", "content": "## ✅ Achieved\n- Added checklist item for submitting the expense report by Friday\n\n## 📌 What is left to do\n- [ ] Email the Q2 receipts to Finance\n- [ ] Reconcile the card transactions\n- [ ] Submit the expense report by Friday\n\n## 💡 Learnings\n- Task requires coordination of three distinct activities: receipt submission, transaction reconciliation, and final report submission\n- Friday deadline is a hard constraint for the final submission\n\n## 🔗 Links"}
```

`update_report`

```json
{"oneLiner":"Q2 expense report task initialized with 3 checklist items","tldr":"Task setup complete with receipt email, reconciliation, and Friday submission deadline. Ready to begin work. 📋","content":"## ✅ Achieved\n- Added checklist item for submitting the expense report by Friday\n\n## 📌 What is left to do\n- [ ] Email the Q2 receipts to Finance\n- [ ] Reconcile the card transactions\n- [ ] Submit the expense report by Friday\n\n## 💡 Learnings\n- Task requires coordination of three distinct activities: receipt submission, transaction reconciliation, and final report submission\n- Friday deadline is a hard constraint for the final submission\n\n## 🔗 Links"}
```

### mistral-small-4-baseline / stale_deadline_user_override_production

Deterministic quality: 2/2.

Final assistant content:

```text
I noticed the user's latest note about the app icon on the dark home screen, but there's no explicit action or status change to report. The task remains in "IN PROGRESS" status with the same checklist item pending, and the due date of October 31 is confirmed by the user's manual adjustment. No material changes warrant a report update.
```

### mistral-small-4-baseline / messy_german_transcript_production

Deterministic quality: 10/10.

Final assistant content:

```text
Ich habe die Sprachnotiz transkribiert und die drei konkreten Aufgaben identifiziert:
1. CSV-Export reparieren
2. Sam nach anonymisierten Testdaten fragen
3. Regressionstest laufen lassen

Der Hinweis auf Newsletter ist explizit als "noch nicht aufnehmen" markiert, daher werde ich ihn nicht in die Aufgaben aufnehmen.

Da keine Checkliste existiert, erstelle ich die drei Items und aktualisiere den Status auf "IN PROGRESS" (der ist bereits so gesetzt, also kein Tool-Call nötig). Ich erstelle die Checkliste und veröffentliche den ersten Report.
```

`add_multiple_checklist_items`

```json
{"items": [{"title": "CSV-Export reparieren", "isChecked": false}, {"title": "Sam nach anonymisierten Testdaten fragen", "isChecked": false}, {"title": "Regressionstest laufen lassen", "isChecked": false}]}
```

`update_report`

```json
{"oneLiner": "CSV-Export-Reparatur und Regressionstest in Arbeit", "tldr": "Drei Prioritäten identifiziert: CSV-Export reparieren, Testdaten von Sam anfordern, Regressionstest ausführen. 📊", "content": "# CSV-Export stabilisieren\n\n## ✅ Achieved\n- Sprachnotiz transkribiert und Aufgaben identifiziert\n- Checkliste mit drei Prioritäten erstellt\n\n## 📌 Was noch zu tun ist\n- [ ] CSV-Export reparieren\n- [ ] Sam nach anonymisierten Testdaten fragen\n- [ ] Regressionstest laufen lassen\n\n## 💡 Learnings\n- Der CSV-Export ist aktuell defekt und muss priorisiert werden\n- Testdaten von Sam sind für die Reparatur notwendig\n- Regressionstest folgt auf die Reparatur\n\n## 🔗 Links"}
```

`update_report`

```json
{
  "oneLiner": "CSV-Export-Reparatur und Regressionstest in Arbeit",
  "tldr": "Drei Prioritäten identifiziert: CSV-Export reparieren, Testdaten von Sam anfordern, Regressionstest ausführen. 📊",
  "content": "# CSV-Export stabilisieren\n\n## ✅ Achieved\n- Sprachnotiz transkribiert und Aufgaben identifiziert\n- Checkliste mit drei Prioritäten erstellt\n\n## 📌 Was noch zu tun ist\n- [ ] CSV-Export reparieren\n- [ ] Sam nach anonymisierten Testdaten fragen\n- [ ] Regressionstest laufen lassen\n\n## 💡 Learnings\n- Der CSV-Export ist aktuell defekt und muss priorisiert werden\n- Testdaten von Sam sind für die Reparatur notwendig\n- Regressionstest folgt auf die Reparatur\n\n## 🔗 Links\n"
}
```

### mistral-small-4-baseline / user_completed_item_resurfaced_production

Deterministic quality: 4/5.

`record_observations`

```json
{"observations": [{"text": "QA note at 11:20 indicates duplicate sync events reappeared after reconnecting two devices. Investigation needed; no root cause identified yet. This suggests the fix may be incomplete or there's an edge case not covered.", "priority": "notable", "category": "operational", "target": "both"}]}
```

`update_report`

```json
{"oneLiner": "Duplicate sync fix complete, but issue reappeared after device reconnection", "tldr": "The duplicate-event fix is complete, but QA found the issue reappeared after reconnecting two devices. Investigation needed. 🔍", "content": "## Achieved\n- Fixed duplicate sync events\n\n## 📌 What is left to do\n- [ ] Investigate root cause of duplicate sync events reappearing after device reconnection\n- [ ] Validate fix handles multi-device reconnection scenarios\n\n## 💡 Learnings\n- The duplicate sync fix appears to be incomplete or has an edge case not covered. QA found the issue reappeared after reconnecting two devices, indicating a need for deeper investigation."}
```

`update_report`

```json
{
  "oneLiner": "Duplicate sync fix complete, but issue reappeared after device reconnection",
  "tldr": "The duplicate-event fix is complete, but QA found the issue reappeared after reconnecting two devices. Investigation needed. 🔍",
  "content": "## Achieved\n- Fixed duplicate sync events\n\n## 📌 What is left to do\n- [ ] Investigate root cause of duplicate sync events reappearing after device reconnection\n- [ ] Validate fix handles multi-device reconnection scenarios\n\n## 💡 Learnings\n- The duplicate sync fix appears to be incomplete or has an edge case not covered. QA found the issue reappeared after reconnecting two devices, indicating a need for deeper investigation."
}
```

### mistral-small-4-baseline / spanish_mixed_context_production

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
{"oneLiner": "Bloqueado: esperando credenciales del proveedor", "tldr": "La activación de facturación electrónica está bloqueada. Se han añadido dos pasos pendientes para desbloquear el proceso. 🚧", "content": "## ✅ Achieved\n\n- Se han creado dos nuevos pasos en la lista de verificación para avanzar con la activación\n\n## 📌 What is left to do\n\n- [ ] Llamar al proveedor para pedir las credenciales\n- [ ] Confirmar con Marta la fecha de activación\n\n## 💡 Learnings\n\nEl proceso está bloqueado porque el proveedor externo no ha enviado las credenciales necesarias. Es prioritario contactar al proveedor para obtener esta información y poder continuar con la activación.\n\n## ⚠️ Blockers\n\n- **Proveedor externo**: No ha enviado las credenciales requeridas para la activación de la facturación electrónica.\n\n## 🔗 Links\n\n[Finance systems migration](/tasks/project-finance-migration)"}
```

`update_report`

```json
{
  "oneLiner": "Bloqueado: esperando credenciales del proveedor",
  "tldr": "La activación de facturación electrónica está bloqueada. Se han añadido dos pasos pendientes para desbloquear el proceso. 🚧",
  "content": "## ✅ Achieved\n\n- Se han creado dos nuevos pasos en la lista de verificación para avanzar con la activación\n\n## 📌 What is left to do\n\n- [ ] Llamar al proveedor para pedir las credenciales\n- [ ] Confirmar con Marta la fecha de activación\n\n## 💡 Learnings\n\nEl proceso está bloqueado porque el proveedor externo no ha enviado las credenciales necesarias. Es prioritario contactar al proveedor para obtener esta información y poder continuar con la activación.\n\n## ⚠️ Blockers\n\n- **Proveedor externo**: No ha enviado las credenciales requeridas para la activación de la facturación electrónica.\n\n## 🔗 Links\n\n[Finance systems migration](/tasks/project-finance-migration)"
}
```

### mistral-small-4-baseline / external_link_and_completion_production

Deterministic quality: 5/5.

Final assistant content:

```text
I'll update the checklist item for the merged PR and then publish the initial report.
```

`update_checklist_items`

```json
{"items": [{"id": "item-pr", "isChecked": true, "reason": "PR 482 was merged as stated in the log entry from 2026-07-10T12:00:00Z"}]}
```

`update_report`

```json
{"oneLiner": "PR merged, deployment pending for tomorrow's maintenance window", "tldr": "Migration PR merged, deployment scheduled for tomorrow's maintenance window 🚧", "content": "## ✅ Achieved\n\n- Merged migration pull request #482\n\n## 📌 What is left to do\n\n- [ ] Deploy the migration\n\n## 🔗 Links\n\n- [Merge PR #482](https://github.com/acme/portal/pull/482)\n\n## 💡 Learnings\n\nDeployment is scheduled for tomorrow's maintenance window, so no immediate action needed."}
```

`update_report`

```json
{
  "oneLiner": "PR merged, deployment pending for tomorrow's maintenance window",
  "tldr": "Migration PR merged, deployment scheduled for tomorrow's maintenance window 🚧",
  "content": "## ✅ Achieved\n\n- Merged migration pull request #482\n\n## 📌 What is left to do\n\n- [ ] Deploy the migration\n\n## 🔗 Links\n\n- [Merge PR #482](https://github.com/acme/portal/pull/482)\n\n## 💡 Learnings\n\nDeployment is scheduled for tomorrow's maintenance window, so no immediate action needed."
}
```

### mistral-small-4-baseline / latest_deadline_wins_production

Deterministic quality: 3/3.

`update_task_due_date`

```json
{"dueDate": "2026-11-20"}
```

`update_report`

```json
{"oneLiner": "Demo dataset ready, finalizing script for Nov 20 conference", "tldr": "Demo dataset is complete; finalizing demo script for the confirmed November 20, 2026 customer conference. 📝", "content": "## ✅ Achieved\n- Demo dataset prepared and ready\n- Customer conference slot confirmed by procurement\n- Task due date updated to November 20, 2026\n\n## 📌 What is left to do\n- [ ] Finalize demo script\n\n## 💡 Learnings\n- Timeline has shifted multiple times: original target was September 30, then tentatively moved to October 15, and finally confirmed for November 20, 2026.\n- Procurement has confirmed the customer conference slot, providing a firm deadline.\n\n## 🔗 Links"}
```

`update_report`

```json
{
  "oneLiner": "Demo dataset ready, finalizing script for Nov 20 conference",
  "tldr": "Demo dataset is complete; finalizing demo script for the confirmed November 20, 2026 customer conference. 📝",
  "content": "## ✅ Achieved\n- Demo dataset prepared and ready\n- Customer conference slot confirmed by procurement\n- Task due date updated to November 20, 2026\n\n## 📌 What is left to do\n- [ ] Finalize demo script\n\n## 💡 Learnings\n- Timeline has shifted multiple times: original target was September 30, then tentatively moved to October 15, and finally confirmed for November 20, 2026.\n- Procurement has confirmed the customer conference slot, providing a firm deadline.\n\n## 🔗 Links\n"
}
```

## Failures
- `mistral-small-4-baseline` / `metadata_explicit_production`: inferenceFailed
- `mistral-small-4-baseline` / `german_voice_plan_production`: missingRequiredContent
- `mistral-small-4-baseline` / `user_completed_item_resurfaced_production`: missingRequiredContent
