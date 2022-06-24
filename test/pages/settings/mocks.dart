import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:mocktail/mocktail.dart';

class MockTagsService extends Mock implements TagsService {}

MockTagsService mockTagsServiceWithTags(
  List<StoryTag> storyTags,
) {
  final mock = MockTagsService();

  when(mock.getAllStoryTags).thenAnswer((_) => storyTags);

  return mock;
}

class MockJournalDb extends Mock implements JournalDb {}

MockJournalDb mockJournalDbWithMeasurableTypes(
  List<MeasurableDataType> dataTypes,
) {
  final mock = MockJournalDb();
  when(mock.close).thenAnswer((_) async {});

  when(mock.watchMeasurableDataTypes).thenAnswer(
    (_) => Stream<List<MeasurableDataType>>.fromIterable([dataTypes]),
  );

  return mock;
}

class MockPersistenceLogic extends Mock implements PersistenceLogic {}

class FakeDashboardDefinition extends Fake implements DashboardDefinition {}

class FakeMeasurementData extends Fake implements MeasurementData {}
