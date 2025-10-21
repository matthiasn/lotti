import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/speech/state/player_cubit.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

class MockTagsService extends Mock implements TagsService {}

MockTagsService mockTagsServiceWithTags(
  List<StoryTag> storyTags,
) {
  final mock = MockTagsService();

  return mock;
}

class MockJournalDb extends Mock implements JournalDb {
  Future<void> deleteLoggingDatabase() async {}

  @override
  Stream<Set<String>> watchActiveConfigFlagNames() {
    try {
      final result = super
          .noSuchMethod(Invocation.method(#watchActiveConfigFlagNames, []));
      if (result is Stream<Set<String>>) {
        return result;
      }
    } catch (_) {
      // ignore and fall back
    }
    return Stream<Set<String>>.value(<String>{}).asBroadcastStream();
  }

  @override
  Stream<bool> watchConfigFlag(String flagName) {
    try {
      final result =
          super.noSuchMethod(Invocation.method(#watchConfigFlag, [flagName]));
      if (result is Stream<bool>) {
        return result;
      }
    } catch (_) {
      // ignore and fall back
    }
    return Stream<bool>.value(false).asBroadcastStream();
  }
}

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {}

MockJournalDb mockJournalDbWithMeasurableTypes(
  List<MeasurableDataType> dataTypes,
) {
  final mock = MockJournalDb();
  when(mock.close).thenAnswer((_) async {});

  when(mock.watchMeasurableDataTypes).thenAnswer(
    (_) => Stream<List<MeasurableDataType>>.fromIterable([dataTypes]),
  );

  when(
    () => mock.getJournalEntities(
      types: any(named: 'types'),
      starredStatuses: any(named: 'starredStatuses'),
      privateStatuses: any(named: 'privateStatuses'),
      flaggedStatuses: any(named: 'flaggedStatuses'),
      ids: any(named: 'ids'),
      limit: any(named: 'limit'),
      offset: any(named: 'offset'),
      categoryIds: any(named: 'categoryIds'),
    ),
  ).thenAnswer((_) async => <JournalEntity>[]);

  when(
    () => mock.getTasks(
      ids: any(named: 'ids'),
      starredStatuses: any(named: 'starredStatuses'),
      taskStatuses: any(named: 'taskStatuses'),
      categoryIds: any(named: 'categoryIds'),
      limit: any(named: 'limit'),
      offset: any(named: 'offset'),
    ),
  ).thenAnswer((_) async => <JournalEntity>[]);

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

  when(() => mock.watchConfigFlag(enableMatrixFlag)).thenAnswer(
    (_) => Stream<bool>.fromIterable([enabled]),
  );

  return mock;
}

class MockPersistenceLogic extends Mock implements PersistenceLogic {}

class MockFts5Db extends Mock implements Fts5Db {}

class MockTimeService extends Mock implements TimeService {}

class MockLoggingDb extends Mock implements LoggingDb {}

class MockLoggingService extends Mock implements LoggingService {}

class MockEditorDb extends Mock implements EditorDb {}

class MockEditorStateService extends Mock implements EditorStateService {}

class MockLinkService extends Mock implements LinkService {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

class MockHealthImport extends Mock implements HealthImport {}

class MockSecureStorage extends Mock implements SecureStorage {}

class MockVectorClockService extends Mock implements VectorClockService {}

class MockSettingsDb extends Mock implements SettingsDb {}

class MockAudioPlayerCubit extends Mock implements AudioPlayerCubit {}

class MockNavService extends Mock implements NavService {}

class MockNotificationService extends Mock implements NotificationService {}

class MockOutboxService extends Mock implements OutboxService {}

class FakeDashboardDefinition extends Fake implements DashboardDefinition {}

class FakeHabitDefinition extends Fake implements HabitDefinition {}

class FakeCategoryDefinition extends Fake implements CategoryDefinition {}

class FakeEntryText extends Fake implements EntryText {}

class FakeTaskData extends Fake implements TaskData {}

class FakeMetadata extends Fake implements Metadata {}

class FakeQuillController extends Fake implements QuillController {
  FakeQuillController({TextSelection? selection})
      : _selection = selection ?? const TextSelection.collapsed(offset: 0);

  TextSelection _selection;

  @override
  TextSelection get selection => _selection;

  set selection(TextSelection value) {
    _selection = value;
  }
}

class FakeJournalAudio extends Fake implements JournalAudio {}

class FakeMeasurementData extends Fake implements MeasurementData {}

class FakeHabitCompletionData extends Fake implements HabitCompletionData {}

class MockMaintenance extends Mock implements Maintenance {}

class MockMatrixService extends Mock implements MatrixService {}
