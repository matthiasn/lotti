/// The `## Summary` section of a generated prompt, up to its `## Prompt`
/// section or the end.
final RegExp generatedPromptSummarySection = RegExp(
  r'##\s*Summary\s*\n+([\s\S]*?)(?=##\s*Prompt|$)',
  caseSensitive: false,
);

/// What a generated prompt says of itself in a line or two: its `## Summary`
/// section, else its first line — a response that did not follow the format
/// still gets a summary rather than none.
///
/// One reading for every surface that shows a prompt before it is opened:
/// the task page's prompt card, and the companion chat's preview of it.
String generatedPromptSummary(String response) =>
    generatedPromptSummarySection.firstMatch(response)?.group(1)?.trim() ??
    response.split('\n').first.trim();
