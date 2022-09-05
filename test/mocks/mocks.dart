import 'package:lotti/blocs/audio/player_cubit.dart';
import 'package:lotti/blocs/audio/recorder_cubit.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/sync/connectivity.dart';
import 'package:lotti/sync/fg_bg.dart';
import 'package:lotti/sync/secure_storage.dart';
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

class MockSyncDatabase extends Mock implements SyncDatabase {}

class MockTimeService extends Mock implements TimeService {}

class MockLoggingDb extends Mock implements LoggingDb {}

class MockEditorStateService extends Mock implements EditorStateService {}

class MockLinkService extends Mock implements LinkService {}

class MockHealthImport extends Mock implements HealthImport {}

class MockSecureStorage extends Mock implements SecureStorage {}

class MockVectorClockService extends Mock implements VectorClockService {}

class MockConnectivityService extends Mock implements ConnectivityService {}

class MockFgBgService extends Mock implements FgBgService {}

class MockAudioRecorderCubit extends Mock implements AudioRecorderCubit {}

class MockAudioPlayerCubit extends Mock implements AudioPlayerCubit {}

class MockNavService extends Mock implements NavService {}

class MockNotificationService extends Mock implements NotificationService {}

class FakeDashboardDefinition extends Fake implements DashboardDefinition {}

class FakeTagEntity extends Fake implements TagEntity {}

class FakeEntryText extends Fake implements EntryText {}

class FakeTaskData extends Fake implements TaskData {}

class FakeJournalEntity extends Fake implements JournalEntity {}

class FakeMeasurementData extends Fake implements MeasurementData {}
