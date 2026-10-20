import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/relationships/repository/person_timeline_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

/// Overrides [personTimelineRepositoryProvider] with a repository whose
/// people hold [entries] on their timeline — none by default — for the
/// widget tests that render a person's state but are not about the
/// timeline itself. With [personId], only that person holds them.
Override personTimelineOverride({
  List<JournalEntity> entries = const [],
  String? personId,
}) {
  final repository = MockPersonTimelineRepository();
  when(() => repository.getTimelineEntries(any())).thenAnswer(
    (call) async =>
        personId == null || call.positionalArguments.single == personId
        ? entries
        : const [],
  );
  // The page reads each recording's summary line with its detail; none here.
  when(() => repository.getRecordingSummaries(any())).thenAnswer(
    (_) async =>
        (oneLiners: const <String, String>{}, summaryIds: const <String>{}),
  );
  // A sort's one line is saved as the voice note's summary.
  when(
    () => repository.saveRecordingSummary(
      audioId: any(named: 'audioId'),
      summary: any(named: 'summary'),
      modelId: any(named: 'modelId'),
      categoryId: any(named: 'categoryId'),
    ),
  ).thenAnswer((_) async => true);
  // A spoken capture puts its voice note on the timeline as it is saved.
  when(
    () => repository.addToTimeline(
      personId: any(named: 'personId'),
      entryId: any(named: 'entryId'),
    ),
  ).thenAnswer((_) async => true);
  return personTimelineRepositoryProvider.overrideWithValue(repository);
}
