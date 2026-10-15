import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/relationships/repository/person_timeline_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

/// Overrides [personTimelineRepositoryProvider] with a repository whose
/// people hold [entries] on their timeline — none by default — for the
/// widget tests that render a person's state but are not about the
/// timeline itself.
Override personTimelineOverride({List<JournalEntity> entries = const []}) {
  final repository = MockPersonTimelineRepository();
  when(
    () => repository.getTimelineEntries(any()),
  ).thenAnswer((_) async => entries);
  return personTimelineRepositoryProvider.overrideWithValue(repository);
}
