import 'package:lotti/classes/agents/change_set.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';

import '../agents/test_data/change_set_factories.dart';

/// A task agent's draft of a new version of document [document], waiting
/// for the user, as the task's proposal list carries it — the penguin brief
/// unless told otherwise. [base] is the version it was written over; null
/// for a document that had no text.
PendingSuggestion documentDraft({
  String setId = 'cs-draft',
  String taskId = 'task-1',
  String document = 'doc-brief',
  String tool = 'propose_document_version',
  String? base = 'version-1',
  String markdown =
      '# Brief\n\nFeed the penguins at one.\n\nCount them at '
      'dusk.\n\nReport to the council.',
  String? changeSummary = ' Feeds later, reports to the council. ',
  DateTime? createdAt,
}) {
  final set = makeTestChangeSet(
    id: setId,
    taskId: taskId,
    createdAt: createdAt,
    items: [
      ChangeItem(
        toolName: tool,
        args: {
          'documentId': document,
          'title': 'Brief',
          'baseVersionId': ?base,
          'markdown': markdown,
          'changeSummary': ?changeSummary,
        },
        humanSummary: 'New version of "Brief"',
      ),
    ],
  );
  return PendingSuggestion(
    changeSet: set,
    itemIndex: 0,
    item: set.items.single,
    fingerprint: 'fp-$setId',
  );
}
