/// Matches `<think>…</think>` and `<thinking>…</thinking>` blocks,
/// case-insensitive and across newlines, plus an unclosed one through the end
/// of input, as a stream cut off mid-thought leaves. Only the exact tag names
/// match, optionally with attributes; `<thinking-process>` does not.
///
/// Providers stream their reasoning inside these tags so live views can show
/// it; anything stored must drop it. Conversation history would otherwise
/// resend it, which wastes tokens and, for Gemma 4, violates Google's guidance
/// that past reasoning must not be carried forward; a one-shot result would
/// show it to the user.
final _thinkBlockPattern = RegExp(
  r'<think(?:ing)?(?:\s[^>]*)?>[\s\S]*?(?:</think(?:ing)?>|$)',
  caseSensitive: false,
);

/// Removes `<think>`/`<thinking>` reasoning blocks from assistant [content]
/// before it is stored (see [_thinkBlockPattern]).
/// Returns null when the input is null or nothing meaningful remains after
/// stripping and trimming.
String? stripThinkBlocks(String? content) {
  if (content == null) return null;
  final stripped = content.replaceAll(_thinkBlockPattern, '').trim();
  return stripped.isEmpty ? null : stripped;
}
