import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/projection/input_capture.dart';
import 'package:lotti/features/agents/workflow/task_wake_input_fingerprint.dart';

RenderedSource _source(String id, String text) => RenderedSource(
  contentEntryId: id,
  sourceCreatedAt: DateTime(2026, 3, 15, 9),
  content: <String, Object?>{'entryType': 'text', 'text': text},
);

String _fingerprint({
  String taskState = '- Title: Fix the boiler',
  List<RenderedSource>? sources,
  List<String> links = const ['entry-1', 'project-1'],
  String? categoryKnowledge = 'Plumbing jobs',
  String templateVersionId = 'tv-1',
  String? soulVersionId = 'sv-1',
  String modelId = 'model-1',
}) => taskWakeInputFingerprint(
  taskState: taskState,
  sources:
      sources ??
      [_source('entry-1', 'Valve leaks'), _source('entry-2', 'Seal')],
  linkedEntityIds: links,
  categoryKnowledge: categoryKnowledge,
  templateVersionId: templateVersionId,
  soulVersionId: soulVersionId,
  modelId: modelId,
);

void main() {
  group('taskWakeInputFingerprint', () {
    glados.Glados(
      glados.any.list(glados.any.lowercaseLetters),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'does not depend on the order of sources or links',
      (ids) {
        final distinct = ids.toSet().toList();
        final sources = [for (final id in distinct) _source(id, 'text $id')];
        expect(
          _fingerprint(sources: sources, links: distinct),
          _fingerprint(
            sources: sources.reversed.toList(),
            links: [...distinct.reversed, ...distinct],
          ),
        );
      },
      tags: 'glados',
    );

    test('is stable for identical inputs', () {
      expect(_fingerprint(), _fingerprint());
    });

    test('ignores surrounding whitespace in the category brief', () {
      expect(
        _fingerprint(categoryKnowledge: '  Plumbing jobs\n'),
        _fingerprint(),
      );
      expect(
        _fingerprint(categoryKnowledge: null),
        _fingerprint(categoryKnowledge: ''),
      );
    });

    final base = _fingerprint();
    final changes = <String, String>{
      'task state': _fingerprint(taskState: '- Title: Fix the boiler (done)'),
      'source text': _fingerprint(
        sources: [_source('entry-1', 'Valve leaks'), _source('entry-2', 'New')],
      ),
      'source set': _fingerprint(sources: [_source('entry-1', 'Valve leaks')]),
      'link set': _fingerprint(links: ['entry-1', 'project-1', 'task-9']),
      'category brief': _fingerprint(categoryKnowledge: 'Heating jobs'),
      'template version': _fingerprint(templateVersionId: 'tv-2'),
      'soul version': _fingerprint(soulVersionId: null),
      'model': _fingerprint(modelId: 'model-2'),
    };
    for (final MapEntry(key: what, value: changed) in changes.entries) {
      test('changes when the $what changes', () {
        expect(changed, isNot(base));
      });
    }
  });
}
