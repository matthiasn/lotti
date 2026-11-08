import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/workflow/prompt_fingerprint.dart';
import 'package:openai_dart/openai_dart.dart';

void main() {
  ChatCompletionTool tool(String name) => ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(name: name, description: 'Waddle $name'),
  );

  const head = '## Category Knowledge\n\nPenguins.\n\n## Task Log\n';
  const log = '- [2024-05-02] (id: e1, entry) Counted fish';
  const message = '$head$log\n\n## Current Task Context\nopen';

  Map<String, String> fields({
    String systemPrompt = 'You are a Task Agent.',
    List<String> toolNames = const ['update_report', 'set_task_status'],
    String userMessage = message,
    int? logStart = head.length,
    int? logEnd = head.length + log.length,
    String? activeSummaryId,
  }) {
    final line = promptFingerprint(
      systemPrompt: systemPrompt,
      tools: [for (final name in toolNames) tool(name)],
      userMessage: userMessage,
      logStart: logStart,
      logEnd: logEnd,
      activeSummaryId: activeSummaryId,
    );
    expect(line, startsWith('prompt fingerprint: '));
    return {
      for (final pair
          in line
              .substring('prompt fingerprint: '.length)
              .split(
                ' ',
              ))
        pair.split('=').first: pair.split('=').last,
    };
  }

  test('is stable for an identical prompt', () {
    expect(fields(), fields());
  });

  test('changes only the field of the block that changed', () {
    final base = fields();
    final changed = <String, Map<String, String>>{
      'tools': fields(toolNames: const ['update_report']),
      'system': fields(systemPrompt: 'You are Laura.'),
      'head': fields(
        // Same length, so only the head hash may move.
        userMessage: message.replaceFirst('Penguins.', 'Seals....'),
      ),
      'summary': fields(activeSummaryId: 'summary-1'),
    };
    for (final MapEntry(key: block, value: other) in changed.entries) {
      final differing = {
        for (final key in base.keys)
          if (base[key] != other[key]) key,
      };
      expect(differing, {block}, reason: block);
    }
  });

  test('a longer log changes the length, not the head', () {
    const longer = '$log\n- [2024-05-03] (id: e2, entry) Counted more fish';
    final grown = fields(
      userMessage: '$head$longer\n\n## Current Task Context\nopen',
      logEnd: head.length + longer.length,
    );
    final base = fields();
    expect(grown['head'], base['head']);
    expect(grown['logChars'], '${longer.length}');
    expect(base['logChars'], '${log.length}');
    expect(grown['log'], isNot(base['log']));
  });

  test('a log rewritten at the same length changes only the log hash', () {
    final rewritten = log.replaceFirst('Counted', 'Watched');
    final other = fields(userMessage: message.replaceFirst(log, rewritten));
    final base = fields();
    expect(
      {
        for (final key in base.keys)
          if (base[key] != other[key]) key,
      },
      {'log'},
    );
  });

  test('a message without a compacted log hashes an empty head', () {
    final legacy = fields(logStart: null, logEnd: null);
    expect(legacy['logChars'], '0');
    expect(
      legacy['head'],
      fields(userMessage: 'other', logStart: null)['head'],
    );
  });

  test('carries no prompt text', () {
    final line = promptFingerprint(
      systemPrompt: 'secret system',
      tools: [tool('update_report')],
      userMessage: message,
      logStart: head.length,
      logEnd: head.length + log.length,
      activeSummaryId: 'summary-secret',
    );
    for (final text in ['secret', 'Penguins', 'fish', 'update_report']) {
      expect(line, isNot(contains(text)), reason: text);
    }
  });
}
