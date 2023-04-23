import 'package:bloc_test/bloc_test.dart';
import 'package:lotti/blocs/audio/player_cubit.dart';
import 'package:lotti/blocs/audio/recorder_cubit.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/sync/connectivity.dart';
import 'package:lotti/sync/fg_bg.dart';
import 'package:lotti/sync/imap_client.dart';
import 'package:lotti/sync/secure_storage.dart';
import 'package:lotti/utils/consts.dart';
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

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {}

MockJournalDb mockJournalDbWithMeasurableTypes(
  List<MeasurableDataType> dataTypes,
) {
  final mock = MockJournalDb();
  when(mock.close).thenAnswer((_) async {});

  when(mock.watchMeasurableDataTypes).thenAnswer(
    (_) => Stream<List<MeasurableDataType>>.fromIterable([dataTypes]),
  );

  for (final dataType in dataTypes) {
    when(() => mock.watchMeasurableDataTypeById(dataType.id)).thenAnswer(
      (_) => Stream<MeasurableDataType>.fromIterable([dataType]),
    );
  }

  return mock;
}

MockJournalDb mockJournalDbWithHabits(
  List<HabitDefinition> habitDefinitions,
) {
  final mock = MockJournalDb();
  when(mock.close).thenAnswer((_) async {});

  when(mock.watchHabitDefinitions).thenAnswer(
    (_) => Stream<List<HabitDefinition>>.fromIterable([habitDefinitions]),
  );

  for (final habitDefinition in habitDefinitions) {
    when(() => mock.watchHabitById(habitDefinition.id)).thenAnswer(
      (_) => Stream<HabitDefinition>.fromIterable([habitDefinition]),
    );
  }

  return mock;
}

MockJournalDb mockJournalDbWithSyncFlag({
  required bool enabled,
}) {
  final mock = MockJournalDb();
  when(mock.close).thenAnswer((_) async {});

  when(() => mock.watchConfigFlag(enableSyncFlag)).thenAnswer(
    (_) => Stream<bool>.fromIterable([enabled]),
  );

  return mock;
}

class MockPersistenceLogic extends Mock implements PersistenceLogic {}

class MockFts5Db extends Mock implements Fts5Db {}

class MockTimeService extends Mock implements TimeService {}

class MockLoggingDb extends Mock implements LoggingDb {}

class MockEditorStateService extends Mock implements EditorStateService {}

class MockLinkService extends Mock implements LinkService {}

class MockEntryCubit extends MockBloc<EntryCubit, EntryState>
    implements EntryCubit {}

class MockHealthImport extends Mock implements HealthImport {}

class MockSecureStorage extends Mock implements SecureStorage {}

class MockVectorClockService extends Mock implements VectorClockService {}

class MockConnectivityService extends Mock implements ConnectivityService {}

class MockImapClientManager extends Mock implements ImapClientManager {}

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

class FakeJournalAudio extends Fake implements JournalAudio {}

class FakeMeasurementData extends Fake implements MeasurementData {}

class FakeHabitCompletionData extends Fake implements HabitCompletionData {}

class MockMaintenance extends Mock implements Maintenance {}
