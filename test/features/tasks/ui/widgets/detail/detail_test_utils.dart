import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';

final detailTestDate = DateTime(2024, 3, 15, 10, 30);

final detailTestDueDate = DateTime(2024, 4);

final detailTestCategory = EntityDefinition.categoryDefinition(
  id: 'cat-1',
  createdAt: detailTestDate,
  updatedAt: detailTestDate,
  name: 'Work',
  vectorClock: null,
  private: false,
  active: true,
  color: '#1ca3e3',
);

final detailTestLabel = EntityDefinition.labelDefinition(
  id: 'label-1',
  createdAt: detailTestDate,
  updatedAt: detailTestDate,
  name: 'Bug fix',
  color: '#1ca3e3',
  vectorClock: null,
);

final detailTestTask = Task(
  data: TaskData(
    status: TaskStatus.open(
      id: 'status-1',
      createdAt: detailTestDate,
      utcOffset: 60,
    ),
    title: 'Test detail task',
    statusHistory: [],
    dateTo: detailTestDate.add(const Duration(hours: 2)),
    dateFrom: detailTestDate,
    priority: TaskPriority.p1High,
    due: detailTestDueDate,
  ),
  meta: Metadata(
    id: 'detail-task-id',
    createdAt: detailTestDate,
    dateFrom: detailTestDate,
    dateTo: detailTestDate.add(const Duration(hours: 2)),
    updatedAt: detailTestDate,
    starred: false,
    categoryId: 'cat-1',
    labelIds: ['label-1'],
  ),
  entryText: const EntryText(plainText: 'Task description text'),
);

/// Registers all getIt services needed for EntryController-based widgets.
Future<void> setUpDetailTestGetIt() async {
  await getIt.reset();

  final mockUpdateNotifications = MockUpdateNotifications();
  final mockJournalDb = MockJournalDb();
  final mockEditorStateService = MockEditorStateService();
  final mockEntitiesCacheService = MockEntitiesCacheService();
  final mockTimeService = MockTimeService();
  final mockNavService = MockNavService();

  when(
    () => mockUpdateNotifications.updateStream,
  ).thenAnswer((_) => const Stream.empty());
  when(
    () => mockUpdateNotifications.localUpdateStream,
  ).thenAnswer((_) => const Stream.empty());
  when(
    () => mockEditorStateService.getUnsavedStream(any(), any()),
  ).thenAnswer((_) => Stream<bool>.fromIterable([false]));
  when(() => mockEditorStateService.getDelta(any())).thenReturn(null);
  when(() => mockEditorStateService.getSelection(any())).thenReturn(null);
  when(() => mockEditorStateService.entryIsUnsaved(any())).thenReturn(false);
  when(
    () => mockJournalDb.journalEntityById(any()),
  ).thenAnswer((_) async => null);
  when(() => mockJournalDb.getConfigFlag(any())).thenAnswer((_) async => false);
  when(
    mockTimeService.getStream,
  ).thenAnswer((_) => Stream<JournalEntity?>.fromIterable([]));
  when(mockTimeService.getCurrent).thenReturn(null);
  when(() => mockEntitiesCacheService.getCategoryById(any())).thenReturn(null);
  when(
    () => mockEntitiesCacheService.getCategoryById('cat-1'),
  ).thenReturn(detailTestCategory as CategoryDefinition);
  when(() => mockEntitiesCacheService.getLabelById(any())).thenReturn(null);
  when(
    () => mockEntitiesCacheService.getLabelById('label-1'),
  ).thenReturn(detailTestLabel as LabelDefinition);
  when(() => mockEntitiesCacheService.showPrivateEntries).thenReturn(true);
  when(() => mockNavService.isDesktopMode).thenReturn(true);

  getIt
    ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
    ..registerSingleton<JournalDb>(mockJournalDb)
    ..registerSingleton<EditorStateService>(mockEditorStateService)
    ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
    ..registerSingleton<TimeService>(mockTimeService)
    ..registerSingleton<NavService>(mockNavService)
    ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
    ..registerSingleton<LoggingService>(LoggingService());
}

Future<void> tearDownDetailTestGetIt() async {
  await getIt.reset();
}

/// Dark-themed widget wrapper for detail component tests.
ThemeData detailTestTheme() => DesignSystemTheme.dark();

/// Entry controller that synchronously returns a fixed entry.
class DetailFakeEntryController extends EntryController {
  DetailFakeEntryController(this._entity);

  final JournalEntity _entity;

  @override
  Future<EntryState?> build({required String id}) {
    final value = EntryState.saved(
      entryId: id,
      entry: _entity,
      showMap: false,
      isFocused: false,
      shouldShowEditorToolBar: false,
      formKey: GlobalKey<FormBuilderState>(),
    );
    state = AsyncData(value);
    return SynchronousFuture(value);
  }
}

/// Creates an override for entryControllerProvider with a fixed Task.
Override createDetailEntryOverride(JournalEntity entity) {
  return entryControllerProvider(id: entity.meta.id).overrideWith(
    () => DetailFakeEntryController(entity),
  );
}
