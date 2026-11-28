import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/task_document_source.dart';
import 'package:lotti/features/agents/tools/change_effect.dart';
import 'package:lotti/features/agents/workflow/task_document_tool_handler.dart';

import '../fake_task_document_source.dart';

void main() {
  const taskId = 'task-1';
  const effect = ChangeEffect(key: 'change-set-1:0');
  late FakeTaskDocumentSource source;

  setUp(() => source = FakeTaskDocumentSource());

  Future<({bool success, bool nonRetryable, String output, String? mutated})>
  apply(Map<String, dynamic> args, {ChangeEffect? withEffect = effect}) async {
    final result = await applyDocumentVersion(
      source: source,
      taskId: taskId,
      args: args,
      effect: withEffect,
    );
    return (
      success: result.success,
      nonRetryable: result.nonRetryable,
      output: result.output,
      mutated: result.mutatedEntityId,
    );
  }

  test(
    'writes the confirmed text over its base, as the version of the '
    "confirmation's effect, with ids derived from it",
    () async {
      final result = await apply({
        'documentId': 'doc-1',
        'markdown': '# Brief',
        'baseVersionId': 'version-1',
        'changeSummary': 'Adds next steps.',
      });

      expect(result.success, isTrue);
      expect(result.mutated, 'doc-1');
      final call = source.applied.single;
      expect(call.taskId, taskId);
      expect(call.documentId, 'doc-1');
      expect(call.newTitle, isNull);
      expect(call.markdown, '# Brief');
      expect(call.baseVersionId, 'version-1');
      expect(call.changeSummary, 'Adds next steps.');
      expect(call.changeEffectKey, 'change-set-1:0');
      expect(
        call.documentUuidV5Input,
        effect.entityInput(taskDocumentEffectRole),
      );
      expect(
        call.versionUuidV5Input,
        effect.entityInput(taskDocumentVersionEffectRole),
      );
    },
  );

  test('a new document is created under its proposed title', () async {
    await apply({'newTitle': 'Meeting summary', 'markdown': '# Summary'});

    final call = source.applied.single;
    expect(call.documentId, isNull);
    expect(call.newTitle, 'Meeting summary');
  });

  test(
    'a proposal that can never apply — no text, or no document and no '
    'title — fails for good, without asking the source',
    () async {
      for (final args in [
        {'documentId': 'doc-1', 'markdown': '  '},
        {'markdown': '# Brief'},
      ]) {
        final result = await apply(args);
        expect(result.success, isFalse);
        expect(result.nonRetryable, isTrue);
      }
      expect(source.applied, isEmpty);
    },
  );

  test(
    'a refusal that applying again would repeat withdraws the proposal; a '
    'passing one leaves it to retry',
    () async {
      source.applyOutcome = const TaskDocumentApplyRefused(
        reason: 'the document changed after this version was drafted',
        permanent: true,
      );
      final stale = await apply({'documentId': 'doc-1', 'markdown': 'x'});
      expect(stale.success, isFalse);
      expect(stale.nonRetryable, isTrue);
      expect(
        stale.output,
        'Error: the document changed after this version was drafted.',
      );

      source.applyOutcome = const TaskDocumentApplyRefused(
        reason: 'the version could not be stored',
        permanent: false,
      );
      final failed = await apply({'documentId': 'doc-1', 'markdown': 'x'});
      expect(failed.success, isFalse);
      expect(failed.nonRetryable, isFalse);
    },
  );

  test(
    'without a confirmation effect, each dispatch derives ids of its own '
    'and records no provenance',
    () async {
      await apply({'documentId': 'doc-1', 'markdown': 'x'}, withEffect: null);
      await apply({'documentId': 'doc-1', 'markdown': 'x'}, withEffect: null);

      expect(source.applied.map((c) => c.changeEffectKey), [null, null]);
      expect(
        source.applied[0].versionUuidV5Input,
        isNot(source.applied[1].versionUuidV5Input),
      );
    },
  );

  test('says so when the documents feature is not wired', () async {
    final result = await applyDocumentVersion(
      source: null,
      taskId: taskId,
      args: const {'documentId': 'doc-1', 'markdown': 'x'},
      effect: effect,
    );

    expect(result.success, isFalse);
    expect(result.errorMessage, 'write_document_version is not configured');
  });
}
