import 'package:lotti/features/ai_chat/ui/controllers/chat_stream_utils.dart';

/// Streaming events emitted by [ChatStreamParser].
abstract class ChatStreamEvent {
  const ChatStreamEvent();
}

class VisibleAppend extends ChatStreamEvent {
  const VisibleAppend(this.text);
  final String text;
}

class ThinkingFinal extends ChatStreamEvent {
  const ThinkingFinal(this.text);
  final String text;
}

/// Incremental parser that consumes streamed chunks and emits semantic events
/// for visible text appends and finalized thinking blocks.
class ChatStreamParser {
  String _pendingOpenTagTail = '';
  bool _inThinkingStream = false;
  String _activeCloseToken = '';
  final StringBuffer _thinkingBuffer = StringBuffer();
  bool _pendingSoftBreak = false;

  List<ChatStreamEvent> processChunk(String rawChunk) {
    // Merge any carried partial opener from previous chunk
    var chunk = _pendingOpenTagTail + rawChunk;
    _pendingOpenTagTail = '';

    // Carry partial opener tail to the next chunk, if any
    final carry = ChatStreamUtils.computeOpenTagCarry(chunk);
    if (carry.isNotEmpty) {
      chunk = chunk.substring(0, chunk.length - carry.length);
      _pendingOpenTagTail = carry;
    }

    final events = <ChatStreamEvent>[];
    var index = 0;
    while (index < chunk.length) {
      if (_inThinkingStream) {
        final closeMatch =
            ChatStreamUtils.closeRegexFromOpenToken(_activeCloseToken)
                .firstMatch(chunk.substring(index));
        if (closeMatch == null) {
          _thinkingBuffer.write(chunk.substring(index));
          index = chunk.length;
          break;
        } else {
          final closeIdx = index + closeMatch.start;
          _thinkingBuffer.write(chunk.substring(index, closeIdx));
          final text = _thinkingBuffer.toString();
          _thinkingBuffer.clear();
          _inThinkingStream = false;
          _activeCloseToken = '';
          if (text.trim().isNotEmpty) {
            events.add(ThinkingFinal(text));
          }
          index = closeIdx + closeMatch.group(0)!.length;
          continue;
        }
      } else {
        final earliest = ChatStreamUtils.findEarliestOpenMatch(chunk, index);
        if (earliest == null) {
          final segment = chunk.substring(index);
          final prep = ChatStreamUtils.prepareVisibleChunk(
            segment,
            pendingSoftBreak: _pendingSoftBreak,
          );
          _pendingSoftBreak = prep.pendingSoftBreak;
          final text = prep.text;
          if (text != null && text.isNotEmpty) {
            events.add(VisibleAppend(text));
          }
          break;
        }
        // Emit preceding visible content
        if (earliest.idx > index) {
          final segment = chunk.substring(index, earliest.idx);
          final prep = ChatStreamUtils.prepareVisibleChunk(
            segment,
            pendingSoftBreak: _pendingSoftBreak,
          );
          _pendingSoftBreak = prep.pendingSoftBreak;
          final text = prep.text;
          if (text != null && text.isNotEmpty) {
            events.add(VisibleAppend(text));
          }
        }
        // Enter thinking
        _inThinkingStream = true;
        _activeCloseToken = earliest.closeToken;
        index = earliest.end;
      }
    }
    return events;
  }

  /// Flush any remaining state when the stream ends.
  List<ChatStreamEvent> finish() {
    final events = <ChatStreamEvent>[];
    if (_thinkingBuffer.isNotEmpty) {
      final text = _thinkingBuffer.toString();
      _thinkingBuffer.clear();
      _inThinkingStream = false;
      _activeCloseToken = '';
      if (text.trim().isNotEmpty) {
        events.add(ThinkingFinal(text));
      }
    }
    return events;
  }
}
