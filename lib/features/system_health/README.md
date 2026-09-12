# System health

System health is an on-demand log analysis tool in *Settings → Advanced*. It
reads the diagnostic log files Lotti already writes on the device, strips
anything personal out of them, condenses what is left into a digest, and asks
an AI model for the three findings most worth an engineer's attention. The
result is a short Markdown report the user copies and pastes into a coding
assistant or a bug report.

## What it does for the user

- **Picks the window.** Presets for the last 24 hours, 7 days and 14 days, or
  a custom range of whole days.
- **Uses the logging switches the user already knows.** The same domain
  toggles as *Logging Domains* are embedded on the page; a domain that is on
  is logged *and* analysed. Slow queries are included when slow-query logging
  is on.
- **Proposes a model, lets the user change it.** The default profile's
  thinking model is preselected, the same one the AI popup menu would fall
  back to; the shared model picker offers every agentic text model.
- **Never leaks personal data.** Every message and statement is redacted
  before it is grouped, shown, sent to a model or copied: emails, UUIDs,
  Matrix ids, credentials, home-directory paths, IP addresses, phone numbers
  and URL query strings become bracketed placeholders, and the report says so.
- **Stays short.** Three findings, each with the evidence, the likely cause
  and one next step. The full digest sits underneath, collapsed, for whoever
  wants to check the reasoning.
- **Copies in one tap.** The whole report, digest included, lands on the
  clipboard as Markdown.
- **Keeps what it wrote.** Every report is saved as a Markdown file in a
  `system_health` folder beside the log files, and the newest one is shown
  again the next time the page opens, even after a restart.
- **Degrades honestly.** No model, or a failed model call, still yields the
  digest with a note saying why the findings are missing.

## What it owns

The range and report models, the log-file reader and its line grammar, the
redactor, the digest builder, the report renderer, the one-off inference call
for the findings, the page state, and the Settings page. Everything up to the
page is UI-free so a scheduled check can run the same analysis later.

It does **not** own the log files or their format — `LoggingService`,
`DomainLogger` and the database's slow-query interceptor write those — nor the
logging-domain toggles, which belong to the Settings logging page and are
embedded here as they are. It does not own model configuration either; it
reads the default profile and the model catalog the AI feature maintains.

## Where the code sits

- `domain/` — `SystemHealthRange`, the parsed `LogRecord` / `SlowQueryRecord`,
  the `LogDigest` buckets and the `SystemHealthReport`.
- `service/` — `LogFileReader`, `LogRedactor`, `LogDigestBuilder`,
  `SystemHealthReportBuilder`, `SystemHealthFindingsInference`, the
  `SystemHealthAnalyzer` that orchestrates them, and the
  `SystemHealthReportStore` that keeps reports on disk.
- `state/` — `SystemHealthController` and the analyzer / default-model
  providers.
- `ui/` — `SystemHealthPage` (mobile chrome) and `SystemHealthBody` (hosted by
  the Settings V2 detail pane).

How the files are selected, what the digest keeps, and how the redaction and
the size budget work are in
[knowledge/features/system_health.md](../../../knowledge/features/system_health.md).
