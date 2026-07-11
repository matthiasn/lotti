# Local Task-Agent Inference Eval

Provider: `Task Agent Eval (genericOpenAi)` (genericOpenAi) at `https://api.melious.ai/v1`

| Profile | Model | Scenario | Prompt | Pass | Quality | Retry | Latency | Tool calls | Failure |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: | --- | --- |
| mistral-small-4-quality | `mistral-small-4-119b-instruct` | german_voice_plan_qualityFocused | qualityFocused | no | 91% | no | 4017 ms | add_multiple_checklist_items, update_report | missingRequiredContent |
| mistral-small-4-quality | `mistral-small-4-119b-instruct` | messy_german_transcript_qualityFocused | qualityFocused | no | 50% | no | 2431 ms | update_report | missingExpectedToolCall |
| mistral-small-4-quality | `mistral-small-4-119b-instruct` | user_completed_item_resurfaced_qualityFocused | qualityFocused | yes | 100% | no | 2012 ms | update_report | none |
| mistral-small-4-quality | `mistral-small-4-119b-instruct` | spanish_mixed_context_qualityFocused | qualityFocused | yes | 100% | no | 3452 ms | add_multiple_checklist_items, update_report | none |
| mistral-small-4-quality | `mistral-small-4-119b-instruct` | latest_deadline_wins_qualityFocused | qualityFocused | yes | 100% | no | 2672 ms | update_task_due_date, update_report | none |

## Case Details

### mistral-small-4-quality / german_voice_plan_qualityFocused

Deterministic quality: 10/11.

Final assistant content:

```text
Ich erstelle die konkreten Checklisteneinträge basierend auf der Sprachnotiz vom 10. Juli 2026.
```

`add_multiple_checklist_items`

```json
{"items": [{"title": "API-Umfang mit Ben klären", "isChecked": false}, {"title": "Figma-Prototyp fertig machen", "isChecked": false}, {"title": "Anmeldung implementieren", "isChecked": false}, {"title": "Security-Review von Lea einholen", "isChecked": false}]}
```

`update_report`

```json
{"oneLiner": "Checkliste erstellt, API-Klärung als nächster Schritt", "tldr": "Beta-Vorbereitung läuft, 4 konkrete Schritte in der Checkliste. 🚀", "content": "## ✅ Achieved\n\n- Checkliste mit 4 konkreten Arbeitsschritten erstellt\n\n## 📌 What is left to do\n\n- [ ] API-Umfang mit Ben klären\n- [ ] Figma-Prototyp fertig machen\n- [ ] Anmeldung implementieren\n- [ ] Security-Review von Lea einholen\n\n## 💡 Learnings\n\n- Klare Abfolge der Beta-Vorbereitung definiert: API → Design → Implementierung → Security"}
```

### mistral-small-4-quality / messy_german_transcript_qualityFocused

Deterministic quality: 5/10.

Final assistant content:

```text
Ich habe die Sprachnotiz transkribiert und die drei konkreten Aufgaben identifiziert:
1. CSV-Export reparieren
2. Sam nach anonymisierten Testdaten fragen
3. Regressionstest laufen lassen

Der Hinweis auf Newsletter wurde explizit als "noch nicht aufnehmen" markiert, daher wird er nicht in die Aufgaben aufgenommen.

Da dies der erste Wake ist und keine priorisierten Metadaten oder Labels gesetzt wurden, und da keine Zeitverfolgung oder Statusänderungen erforderlich sind, werde ich jetzt den ersten Bericht veröffentlichen.
```

`update_report`

```json
{"oneLiner": "CSV-Export-Reparatur und Regressionstest in Arbeit", "tldr": "Drei klare Aufgaben identifiziert: CSV-Export reparieren, Testdaten von Sam anfordern, Regressionstest ausführen. 📊🔧", "content": "# CSV-Export stabilisieren\n\n## ✅ Achieved\n- Sprachnotiz transkribiert und Aufgaben identifiziert\n- Drei konkrete nächste Schritte definiert\n\n## 📌 What is left to do\n- [ ] CSV-Export reparieren\n- [ ] Sam nach anonymisierten Testdaten fragen\n- [ ] Regressionstest laufen lassen\n\n## 💡 Learnings\n- Der Nutzer hat explizit priorisiert: Newsletter-Entwicklung wurde bewusst zurückgestellt, um sich auf die kritischen CSV-Export-Probleme zu konzentrieren."}
```

### mistral-small-4-quality / user_completed_item_resurfaced_qualityFocused

Deterministic quality: 5/5.

`update_report`

```json
{"oneLiner": "Duplicate sync fix complete, but reoccurrence detected", "tldr": "The duplicate sync fix is complete, but QA found reoccurrence after device reconnection. Investigation needed. 🔍", "content": "## ✅ Achieved\n- Fixed duplicate sync events\n\n## 📌 What is left to do\n- [ ] Investigate root cause of duplicate sync events reappearing after device reconnection\n\n## 💡 Learnings\n- The duplicate sync fix was initially successful, but a reoccurrence was observed after reconnecting two devices. This suggests the fix may not fully address the underlying issue or there's a race condition during reconnection.\n\n## ⚠️ Blockers\n- Duplicate sync events reappeared once after reconnecting two devices (QA note at 2026-07-10T11:20:00Z). Investigation is needed; no root cause identified yet."}
```

### mistral-small-4-quality / spanish_mixed_context_qualityFocused

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
{"oneLiner": "Bloqueado: esperando credenciales del proveedor", "tldr": "Activación de facturación electrónica en pausa. Se han añadido dos tareas pendientes para desbloquear el proceso. 🚧</tldr>", "content": "## ✅ Achieved\n\n- Añadidos dos pasos a la lista de verificación para avanzar con la activación\n\n## 📌 What is left to do\n\n- [ ] Llamar al proveedor para pedir las credenciales\n- [ ] Confirmar con Marta la fecha de activación\n\n## 💡 Learnings\n\nEl proceso está bloqueado por falta de credenciales del proveedor externo. Es prioritario contactar al proveedor para obtener la información necesaria y continuar con la activación.\n\n## ⚠️ Blockers\n\n- El proveedor externo no ha enviado las credenciales requeridas para la activación de la facturación electrónica.\n\n## 🔗 Links\n"}
```

### mistral-small-4-quality / latest_deadline_wins_qualityFocused

Deterministic quality: 3/3.

`update_task_due_date`

```json
{"dueDate": "2026-11-20"}
```

`update_report`

```json
{"oneLiner": "Demo dataset ready, awaiting demo script for November 20 conference", "tldr": "Enterprise demo due November 20, 2026. Dataset prepared, script in progress. 🎯", "content": "## ✅ Achieved\n- Demo dataset prepared and ready\n- Customer conference slot confirmed by procurement\n- Task due date updated to November 20, 2026\n\n## 📌 What is left to do\n- [ ] Finalize demo script\n\n## 💡 Learnings\n- Timeline shifted from September 30 → October 15 → November 20 based on procurement and customer conference scheduling\n- Dataset preparation completed ahead of schedule, allowing focus on script finalization\n\n## 🔗 Links"}
```

## Failures
- `mistral-small-4-quality` / `german_voice_plan_qualityFocused`: missingRequiredContent
- `mistral-small-4-quality` / `messy_german_transcript_qualityFocused`: missingExpectedToolCall
