import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/task_document_data.dart';

import 'task_document_fixtures.dart';

void main() {
  Map<String, dynamic> roundTrip(Object value) =>
      jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

  group('TaskDocumentData -', () {
    test(
      'survives a sync round trip with its current version, and without one '
      'before the first version is written',
      () {
        final withVersion = TaskDocumentData(
          title: 'Client one-pager',
          current: taskDocumentRef(3, second: 7),
        );
        const empty = TaskDocumentData(title: 'Meeting summary');

        expect(
          TaskDocumentData.fromJson(roundTrip(withVersion)),
          withVersion,
        );
        expect(TaskDocumentData.fromJson(roundTrip(empty)), empty);
        expect(TaskDocumentData.fromJson(roundTrip(empty)).current, isNull);
      },
    );
  });

  group('TaskDocumentVersionData -', () {
    test('survives a sync round trip with its provenance', () {
      const version = TaskDocumentVersionData(
        documentId: 'task-document',
        number: 4,
        markdown: '# Next steps\n\n- Share the rollout plan',
        author: TaskDocumentAuthor.agent,
        baseVersionId: 'version-3',
        changeSummary: 'Adds dated next steps.',
        changeSetId: 'change-set-1',
        changeItemId: 'change-item-1',
      );

      expect(TaskDocumentVersionData.fromJson(roundTrip(version)), version);
    });

    test(
      'an author a newer build added reads as the user, so an older device '
      'still shows the version instead of failing to decode it',
      () {
        final json = roundTrip(
          const TaskDocumentVersionData(
            documentId: 'task-document',
            number: 1,
            markdown: 'Text',
            author: TaskDocumentAuthor.agent,
          ),
        )..['author'] = 'someFutureAuthor';

        expect(
          TaskDocumentVersionData.fromJson(json).author,
          TaskDocumentAuthor.user,
        );
      },
    );
  });
}
