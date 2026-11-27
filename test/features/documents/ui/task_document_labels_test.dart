import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/task_document_data.dart';
import 'package:lotti/features/documents/ui/task_document_labels.dart';
import 'package:lotti/l10n/app_localizations_en.dart';

import '../../../classes/task_document_fixtures.dart';

void main() {
  final messages = AppLocalizationsEn();

  test('a version says who wrote it: the user, the agent, or a restore by '
      'the user', () {
    expect(
      taskDocumentAuthorship(messages, taskDocumentVersionEntry()),
      'Written by you',
    );
    expect(
      taskDocumentAuthorship(
        messages,
        taskDocumentVersionEntry(author: TaskDocumentAuthor.agent),
      ),
      'Written by the agent',
    );
    final restored = taskDocumentVersionEntry(number: 3);
    expect(
      taskDocumentAuthorship(
        messages,
        restored.copyWith(
          data: restored.data.copyWith(restoredFromVersionId: 'version-1'),
        ),
      ),
      'Restored by you',
    );
  });

  test('the version line is its number, its author and its age', () {
    expect(
      taskDocumentVersionLine(
        messages,
        taskDocumentVersionEntry(number: 4),
        now: taskDocFixtureEpoch.add(const Duration(minutes: 5)),
      ),
      'v4 · Written by you · 5 min ago',
    );
  });
}
