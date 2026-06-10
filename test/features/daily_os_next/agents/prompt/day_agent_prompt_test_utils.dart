import 'dart:convert';

import 'package:lotti/features/daily_os_next/agents/prompt/day_agent_prompt_sections.dart';

/// Parses a rendered day-agent tagged-plaintext payload so tests can assert on
/// individual sections without re-implementing the `<tag>…</tag>` grammar.
///
/// Section bodies are extracted between `<tag>\n` and `\n</tag>`; since the
/// builder neutralizes every tag literal inside section bodies, each tag's
/// markers appear exactly once and the extraction is unambiguous.
class ParsedDayAgentPrompt {
  ParsedDayAgentPrompt(this.raw);

  /// The full rendered payload.
  final String raw;

  /// The raw body of [tag], or null when the section is absent.
  String? section(String tag) {
    final open = '<$tag>\n';
    final close = '\n</$tag>';
    final start = raw.indexOf(open);
    if (start < 0) return null;
    final bodyStart = start + open.length;
    final end = raw.indexOf(close, bodyStart);
    if (end < 0) return null;
    return raw.substring(bodyStart, end);
  }

  /// The JSON-decoded body of [tag] (a `Map`/`List`), or null when absent.
  Object? json(String tag) {
    final body = section(tag);
    return body == null ? null : jsonDecode(body);
  }

  /// Whether [tag]'s section is present.
  bool has(String tag) => section(tag) != null;

  /// The position of [tag]'s opening marker in [raw] (`-1` when absent).
  int indexOf(String tag) => raw.indexOf('<$tag>\n');

  /// The present section tags in document order — for prefix/KV-cache ordering
  /// assertions that previously inspected JSON map key order.
  List<String> get tagsInOrder {
    final present = [
      for (final tag in DayAgentPromptTags.all)
        if (has(tag)) tag,
    ]..sort((a, b) => indexOf(a).compareTo(indexOf(b)));
    return present;
  }
}
