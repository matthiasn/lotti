import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:openai_dart/openai_dart.dart';

/// A content-free line naming the state of every block that can void a
/// wake's cached prompt prefix: the tool list and the system prompt (sent
/// ahead of the messages), the user message's head before the task log, the
/// log's length and content, and the fold summary it starts from.
///
/// Logged once per wake. Two wakes whose opening request missed the cache can
/// be compared field by field: the first hash that differs names the block
/// that changed. The log normally grows between wakes, so its hash moves with
/// its length; a changed `log` at an unchanged `logChars` is a rewrite. Hashes are truncated SHA-256, so nothing of the prompt is
/// recoverable from the line. [logStart]/[logEnd] are the user message's log
/// offsets, null when the wake rendered no compacted log.
String promptFingerprint({
  required String systemPrompt,
  required List<ChatCompletionTool> tools,
  required String userMessage,
  required int? logStart,
  required int? logEnd,
  required String? activeSummaryId,
}) {
  final toolsJson = jsonEncode([for (final tool in tools) tool.toJson()]);
  final head = userMessage.substring(0, logStart ?? 0);
  final log = logStart != null && logEnd != null
      ? userMessage.substring(logStart, logEnd)
      : '';
  return 'prompt fingerprint: tools=${tools.length}/${_hash(toolsJson)} '
      'system=${_hash(systemPrompt)} head=${_hash(head)} '
      'logChars=${log.length} log=${_hash(log)} '
      'summary=${activeSummaryId == null ? '-' : _hash(activeSummaryId)} '
      'messageChars=${userMessage.length}';
}

String _hash(String text) =>
    sha256.convert(utf8.encode(text)).toString().substring(0, 8);
