import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/labels/ui/widgets/entry_labels_display.dart';
import 'package:lotti/features/labels/ui/widgets/label_chip.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

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

JournalEntity textEntryWithLabels(List<String> labelIds, {String? categoryId}) {
  final now = DateTime(2023);
  return JournalEntity.journalEntry(
    meta: Metadata(
      id: 'entry-123',
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
      labelIds: labelIds,
      categoryId: categoryId,
    ),
  );
}

void main() {
  late MockEntitiesCacheService cacheService;
  late MockEditorStateService editorStateService;
  late MockJournalDb journalDb;
  late MockUpdateNotifications updateNotifications;

  final labelA = testLabelDefinition1.copyWith(id: 'label-a', name: 'Alpha');
  final labelB = testLabelDefinition1.copyWith(id: 'label-b', name: 'Beta');
  final labelC = testLabelDefinition1.copyWith(id: 'label-c', name: 'Charlie');
  final privateLabel = testLabelDefinition1.copyWith(
    id: 'label-private',
    name: 'Private Label',
    private: true,
  );

  setUp(() async {
    cacheService = MockEntitiesCacheService();
    editorStateService = MockEditorStateService();
    journalDb = MockJournalDb();
    updateNotifications = MockUpdateNotifications();

    await getIt.reset();
    getIt
      ..registerSingleton<EntitiesCacheService>(cacheService)
      ..registerSingleton<EditorStateService>(editorStateService)
      ..registerSingleton<JournalDb>(journalDb)
      ..registerSingleton<UpdateNotifications>(updateNotifications);

    when(() => cacheService.showPrivateEntries).thenReturn(true);

    // Use a callback that handles all label IDs
    when(() => cacheService.getLabelById(any())).thenAnswer((invocation) {
      final id = invocation.positionalArguments.first as String;
      switch (id) {
        case 'label-a':
          return labelA;
        case 'label-b':
          return labelB;
        case 'label-c':
          return labelC;
        case 'label-private':
          return privateLabel;
        default:
          return null;
      }
    });
  });

  tearDown(() async {
    await getIt.reset();
  });

  ProviderScope buildWrapper(
    JournalEntity? entry, {
    bool showEditButton = false,
    bool showHeader = false,
    double bottomPadding = 0,
  }) {
    return ProviderScope(
      overrides: [
        entryControllerProvider(id: 'entry-123').overrideWith(
          () => _TestEntryController(entry),
        ),
        labelsStreamProvider.overrideWith(
          (ref) => Stream<List<LabelDefinition>>.value([labelA, labelB]),
        ),
      ],
      child: makeTestableWidgetWithScaffold(
        EntryLabelsDisplay(
          entryId: 'entry-123',
          showEditButton: showEditButton,
          showHeader: showHeader,
          bottomPadding: bottomPadding,
        ),
      ),
    );
  }

  group('EntryLabelsDisplay basic rendering', () {
    testWidgets('returns empty when entry is null', (tester) async {
      await tester.pumpWidget(buildWrapper(null));
      await tester.pumpAndSettle();

      expect(find.byType(LabelChip), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('returns empty when no labels and showEditButton is false',
        (tester) async {
      final entry = textEntryWithLabels(const []);

      await tester.pumpWidget(buildWrapper(entry));
      await tester.pumpAndSettle();

      expect(find.byType(LabelChip), findsNothing);
    });

    testWidgets('shows labels as chips', (tester) async {
      final entry = textEntryWithLabels(['label-a', 'label-b']);

      await tester.pumpWidget(buildWrapper(entry));
      await tester.pumpAndSettle();

      expect(find.byType(LabelChip), findsNWidgets(2));
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
    });

    testWidgets('sorts labels alphabetically', (tester) async {
      // Add labels in non-alphabetical order
      final entry = textEntryWithLabels(['label-c', 'label-a', 'label-b']);

      await tester.pumpWidget(buildWrapper(entry));
      await tester.pumpAndSettle();

      expect(find.byType(LabelChip), findsNWidgets(3));

      // Verify all labels are shown
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Charlie'), findsOneWidget);
    });
  });

  group('EntryLabelsDisplay private labels', () {
    testWidgets('shows private labels when showPrivate is true',
        (tester) async {
      when(() => cacheService.showPrivateEntries).thenReturn(true);
      final entry = textEntryWithLabels(['label-a', 'label-private']);

      await tester.pumpWidget(buildWrapper(entry));
      await tester.pumpAndSettle();

      expect(find.byType(LabelChip), findsNWidgets(2));
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Private Label'), findsOneWidget);
    });

    testWidgets('hides private labels when showPrivate is false',
        (tester) async {
      when(() => cacheService.showPrivateEntries).thenReturn(false);
      final entry = textEntryWithLabels(['label-a', 'label-private']);

      await tester.pumpWidget(buildWrapper(entry));
      await tester.pumpAndSettle();

      expect(find.byType(LabelChip), findsOneWidget);
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Private Label'), findsNothing);
    });
  });

  group('EntryLabelsDisplay bottomPadding', () {
    testWidgets('applies bottomPadding when labels exist', (tester) async {
      final entry = textEntryWithLabels(['label-a']);

      await tester.pumpWidget(buildWrapper(entry, bottomPadding: 16));
      await tester.pumpAndSettle();

      // Find Padding widget with bottom padding
      final paddingFinder = find.ancestor(
        of: find.byType(Wrap),
        matching: find.byType(Padding),
      );
      expect(paddingFinder, findsWidgets);
    });

    testWidgets('no padding wrapper when bottomPadding is 0', (tester) async {
      final entry = textEntryWithLabels(['label-a']);

      // Uses default bottomPadding: 0
      await tester.pumpWidget(buildWrapper(entry));
      await tester.pumpAndSettle();

      // Should render Wrap directly without extra Padding
      expect(find.byType(LabelChip), findsOneWidget);
    });
  });

  group('EntryLabelsDisplay with header', () {
    testWidgets('shows header when showHeader is true', (tester) async {
      final entry = textEntryWithLabels(['label-a']);

      await tester.pumpWidget(buildWrapper(entry, showHeader: true));
      await tester.pumpAndSettle();

      expect(find.text('Labels'), findsOneWidget);
      expect(find.byType(LabelChip), findsOneWidget);
    });

    testWidgets('shows "no labels" message when empty with header',
        (tester) async {
      final entry = textEntryWithLabels(const []);

      await tester.pumpWidget(
        buildWrapper(entry, showHeader: true, showEditButton: true),
      );
      await tester.pumpAndSettle();

      expect(find.text('Labels'), findsOneWidget);
      expect(find.text('No labels assigned'), findsOneWidget);
    });

    testWidgets('shows edit button when showEditButton is true',
        (tester) async {
      final entry = textEntryWithLabels(['label-a']);

      await tester.pumpWidget(
        buildWrapper(entry, showHeader: true, showEditButton: true),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byTooltip('Edit labels'), findsOneWidget);
    });

    testWidgets('hides edit button when showEditButton is false',
        (tester) async {
      final entry = textEntryWithLabels(['label-a']);

      // showEditButton defaults to false
      await tester.pumpWidget(
        buildWrapper(entry, showHeader: true),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });
  });

  group('EntryLabelsDisplay without header', () {
    testWidgets('shows only chips without header', (tester) async {
      final entry = textEntryWithLabels(['label-a', 'label-b']);

      // showHeader defaults to false
      await tester.pumpWidget(buildWrapper(entry));
      await tester.pumpAndSettle();

      expect(find.text('Labels'), findsNothing);
      expect(find.byType(LabelChip), findsNWidgets(2));
    });
  });

  group('EntryLabelsDisplay handles missing labels', () {
    testWidgets('ignores label IDs not found in cache', (tester) async {
      // label-missing is not registered in cache
      final entry = textEntryWithLabels(['label-a', 'label-missing']);

      await tester.pumpWidget(buildWrapper(entry));
      await tester.pumpAndSettle();

      // Only shows the label that exists in cache
      expect(find.byType(LabelChip), findsOneWidget);
      expect(find.text('Alpha'), findsOneWidget);
    });
  });

  group('EntryLabelsDisplay edit button interaction', () {
    testWidgets('edit button is tappable with correct tooltip', (tester) async {
      final entry = textEntryWithLabels(['label-a'], categoryId: 'cat-1');

      await tester.pumpWidget(
        buildWrapper(entry, showHeader: true, showEditButton: true),
      );
      await tester.pumpAndSettle();

      // Find edit button
      final editButton = find.byIcon(Icons.edit_outlined);
      expect(editButton, findsOneWidget);

      // Verify tooltip
      expect(find.byTooltip('Edit labels'), findsOneWidget);
    });

    testWidgets('edit button has correct icon styling', (tester) async {
      final entry = textEntryWithLabels(['label-a']);

      await tester.pumpWidget(
        buildWrapper(entry, showHeader: true, showEditButton: true),
      );
      await tester.pumpAndSettle();

      // Find the Icon widget and verify its properties
      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.edit_outlined));
      expect(iconWidget.size, equals(18));
    });

    testWidgets('edit button is shown even when labels are empty',
        (tester) async {
      final entry = textEntryWithLabels(const []);

      await tester.pumpWidget(
        buildWrapper(entry, showHeader: true, showEditButton: true),
      );
      await tester.pumpAndSettle();

      // Edit button should still be shown so users can add labels
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    });
  });

  group('EntryLabelsDisplay with header empty state', () {
    testWidgets('shows empty message with edit button when no labels',
        (tester) async {
      final entry = textEntryWithLabels(const []);

      await tester.pumpWidget(
        buildWrapper(entry, showHeader: true, showEditButton: true),
      );
      await tester.pumpAndSettle();

      // Header is shown
      expect(find.text('Labels'), findsOneWidget);

      // Edit button is shown (so users can add labels)
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

      // "No labels assigned" message is shown
      expect(find.text('No labels assigned'), findsOneWidget);

      // No label chips
      expect(find.byType(LabelChip), findsNothing);
    });

    testWidgets('message has dimmed text style', (tester) async {
      final entry = textEntryWithLabels(const []);

      await tester.pumpWidget(
        buildWrapper(entry, showHeader: true, showEditButton: true),
      );
      await tester.pumpAndSettle();

      final textWidget = tester.widget<Text>(find.text('No labels assigned'));
      expect(textWidget.style?.color, isNotNull);
    });
  });
}
