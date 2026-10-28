/// Turns Mistral's streamed `delta.content` into plain text, wrapping its
/// reasoning in `<think>…</think>` the way the Gemini and Ollama clients do,
/// so agent internals and skill thoughts show it and conversation history
/// strips it.
///
/// Mistral streams content either as a plain string or as a list of chunks:
/// `text` chunks carry the answer, `thinking` chunks carry the reasoning trace
/// as a list of text chunks (or, defensively, a string). A thinking block can
/// span many deltas, so use one instance per stream.
class MistralStreamContent {
  bool _inThinking = false;

  /// The text for one delta, or null when the delta carries none.
  ///
  /// An open thinking block is closed before the first answer text, before
  /// tool calls ([hasToolCalls]) and when the choice finishes ([finishing]),
  /// so the block is never left open even when the stream ends mid-thought.
  String? next(
    Object? content, {
    bool hasToolCalls = false,
    bool finishing = false,
  }) {
    final out = StringBuffer();
    if (content is String) {
      _writeAnswer(out, content);
    } else if (content is List) {
      for (final part in content) {
        if (part is String) {
          _writeAnswer(out, part);
        } else if (part is Map<String, dynamic>) {
          switch (part['type']) {
            case 'text':
              final text = part['text'];
              if (text is String) _writeAnswer(out, text);
            case 'thinking':
              _writeThinking(out, _thinkingText(part['thinking']));
          }
        }
      }
    } else if (content != null) {
      _writeAnswer(out, content.toString());
    }
    if (_inThinking && (hasToolCalls || finishing)) _close(out);
    return out.isEmpty ? null : out.toString();
  }

  void _writeAnswer(StringBuffer out, String text) {
    if (text.isEmpty) return;
    if (_inThinking) _close(out);
    out.write(text);
  }

  void _writeThinking(StringBuffer out, String text) {
    if (text.isEmpty) return;
    if (!_inThinking) {
      out.write('<think>');
      _inThinking = true;
    }
    // Mistral marks the block's end structurally, so a literal closing tag
    // in the trace is just text. Defuse it, or it would end the block early
    // for every downstream parser and leak the rest of the reasoning.
    out.write(
      text.replaceAllMapped(_closingTag, (m) => '</ ${m.group(1)}'),
    );
  }

  static final _closingTag = RegExp('</(think(?:ing)?)', caseSensitive: false);

  void _close(StringBuffer out) {
    out.write('</think>');
    _inThinking = false;
  }

  static String _thinkingText(Object? thinking) {
    if (thinking is String) return thinking;
    if (thinking is! List) return '';
    return thinking
        .map(
          (part) => part is Map<String, dynamic> && part['text'] is String
              ? part['text'] as String
              : part is String
              ? part
              : '',
        )
        .join();
  }
}
