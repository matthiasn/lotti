import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/initial_modal_page_content.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../../mocks/mocks.dart';
import '../../../../../../test_data/test_data.dart';
import '../../../../../../widget_test_utils.dart';

class _TestEntryController extends EntryController {
  _TestEntryController(this._entry);

  final JournalEntity? _entry;

  @override
  Future<EntryState?> build({required String id}) async {
    final entry = _entry;
    if (entry == null) return null;
    return EntryState.saved(
      entryId: id,
      entry: entry,
      showMap: false,
      isFocused: false,
      shouldShowEditorToolBar: false,
    );
  }
}

class MockTagsService extends Mock implements TagsService {}

JournalEntity textEntry({List<String>? labelIds}) {
  final now = DateTime(2023);
  return JournalEntity.journalEntry(
    meta: Metadata(
      id: 'entry-123',
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
      labelIds: labelIds,
    ),
  );
}

JournalEntity taskEntry({List<String>? labelIds}) {
  final now = DateTime(2023);
  return JournalEntity.task(
    meta: Metadata(
      id: 'task-123',
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
      labelIds: labelIds,
    ),
    data: TaskData(
      status: TaskStatus.open(
        id: 'status-1',
        createdAt: now,
        utcOffset: now.timeZoneOffset.inMinutes,
      ),
      dateFrom: now,
      dateTo: now,
      statusHistory: [],
      title: 'Test Task',
    ),
  );
}

void main() {
  late MockEntitiesCacheService cacheService;
  late MockEditorStateService editorStateService;
  late MockJournalDb journalDb;
  late MockUpdateNotifications updateNotifications;
  late MockLinkService linkService;
  late MockTagsService tagsService;
  late ValueNotifier<int> pageIndexNotifier;

  setUp(() async {
    cacheService = MockEntitiesCacheService();
    editorStateService = MockEditorStateService();
    journalDb = MockJournalDb();
    updateNotifications = MockUpdateNotifications();
    linkService = MockLinkService();
    tagsService = MockTagsService();
    pageIndexNotifier = ValueNotifier<int>(0);

    await getIt.reset();
    getIt
      ..registerSingleton<EntitiesCacheService>(cacheService)
      ..registerSingleton<EditorStateService>(editorStateService)
      ..registerSingleton<JournalDb>(journalDb)
      ..registerSingleton<UpdateNotifications>(updateNotifications)
      ..registerSingleton<LinkService>(linkService)
      ..registerSingleton<TagsService>(tagsService);

    when(() => cacheService.showPrivateEntries).thenReturn(true);
    when(() => cacheService.getLabelById(any())).thenReturn(null);
  });

  tearDown(() async {
    pageIndexNotifier.dispose();
    await getIt.reset();
  });

  ProviderScope buildWrapper(JournalEntity? entry) {
    return ProviderScope(
      overrides: [
        entryControllerProvider(id: entry?.id ?? 'entry-123').overrideWith(
          () => _TestEntryController(entry),
        ),
        labelsStreamProvider.overrideWith(
          (ref) => Stream<List<LabelDefinition>>.value([
            testLabelDefinition1,
            testLabelDefinition2,
          ]),
        ),
      ],
      child: makeTestableWidgetWithScaffold(
        InitialModalPageContent(
          entryId: entry?.id ?? 'entry-123',
          linkedFromId: null,
          inLinkedEntries: false,
          link: null,
          pageIndexNotifier: pageIndexNotifier,
        ),
      ),
    );
  }

  group('InitialModalPageContent ModernLabelsItem integration', () {
    testWidgets('shows Labels action item for non-task entries',
        (tester) async {
      final entry = textEntry();

      await tester.pumpWidget(buildWrapper(entry));
      await tester.pumpAndSettle();

      // Find the Labels action item by icon and text
      expect(find.byIcon(MdiIcons.labelOutline), findsOneWidget);
      expect(find.text('Labels'), findsOneWidget);
    });

    testWidgets('shows Labels action item subtitle', (tester) async {
      final entry = textEntry();

      await tester.pumpWidget(buildWrapper(entry));
      await tester.pumpAndSettle();

      expect(
        find.text('Assign labels to organize this entry'),
        findsOneWidget,
      );
    });

    testWidgets('hides Labels action item for Task entries', (tester) async {
      final task = taskEntry();

      await tester.pumpWidget(buildWrapper(task));
      await tester.pumpAndSettle();

      // ModernLabelsItem should return SizedBox.shrink for tasks
      // There should be no label icon in the modal for tasks
      expect(find.byIcon(MdiIcons.labelOutline), findsNothing);
    });

    testWidgets('hides Labels action item when entry is null', (tester) async {
      await tester.pumpWidget(buildWrapper(null));
      await tester.pumpAndSettle();

      // ModernLabelsItem should return SizedBox.shrink when entry is null
      expect(find.byIcon(MdiIcons.labelOutline), findsNothing);
    });

    testWidgets('Labels item appears in menu with icon and text',
        (tester) async {
      final entry = textEntry();

      await tester.pumpWidget(buildWrapper(entry));
      await tester.pumpAndSettle();

      // Find the labels item icon
      final labelIcon = find.byIcon(MdiIcons.labelOutline);
      expect(labelIcon, findsOneWidget);

      // Find labels text
      expect(find.text('Labels'), findsOneWidget);

      // Find labels subtitle
      expect(
        find.text('Assign labels to organize this entry'),
        findsOneWidget,
      );
    });
  });

  group('InitialModalPageContent link actions', () {
    testWidgets('renders Link from item', (tester) async {
      final entry = textEntry();

      await tester.pumpWidget(buildWrapper(entry));
      await tester.pumpAndSettle();

      // Find the "Link from" item (localized string)
      final linkFromFinder = find.text('Link from');
      expect(linkFromFinder, findsOneWidget);
    });

    testWidgets('renders Link to item', (tester) async {
      final entry = textEntry();

      await tester.pumpWidget(buildWrapper(entry));
      await tester.pumpAndSettle();

      // Find the "Link to" item (localized string)
      final linkToFinder = find.text('Link to');
      expect(linkToFinder, findsOneWidget);
    });
  });
}
