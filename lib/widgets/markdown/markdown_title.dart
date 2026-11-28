/// [markdown] without a leading level-one heading that only repeats
/// [title] — the surface already shows the title above the text, and saying
/// it twice, with a rule under each, reads as two headers.
///
/// Compared trimmed and without case. Any other first heading stays: it is
/// part of what the author wrote, not a repeat. The markdown itself is never
/// changed, only what is shown; copying a document copies it whole.
String withoutRepeatedTitle(String markdown, String? title) {
  final wanted = title?.trim().toLowerCase();
  if (wanted == null || wanted.isEmpty) return markdown;
  final lines = markdown.split('\n');
  final first = lines.indexWhere((line) => line.trim().isNotEmpty);
  if (first < 0) return markdown;
  final heading = RegExp(
    r'^#\s+(.*?)\s*#*\s*$',
  ).firstMatch(lines[first].trim());
  if (heading == null || heading.group(1)!.trim().toLowerCase() != wanted) {
    return markdown;
  }
  var rest = first + 1;
  while (rest < lines.length && lines[rest].trim().isEmpty) {
    rest++;
  }
  return lines.sublist(rest).join('\n');
}
