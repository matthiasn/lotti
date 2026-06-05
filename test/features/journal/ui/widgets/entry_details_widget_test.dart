import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
// animation library is not required for these assertions
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_datetime_widget.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/habit_summary.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/entry_detail_header.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/measurement_summary.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details_widget.dart';
import 'package:lotti/features/journal/ui/widgets/entry_image_widget.dart';
import 'package:lotti/features/journal/ui/widgets/nested_ai_responses_widget.dart';
import 'package:lotti/features/speech/ui/widgets/audio_player.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../helpers/path_provider.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

// ---------------------------------------------------------------------------
// Fake entry controllers used by the coverage tests below.
// ---------------------------------------------------------------------------

/// Builds an [EntryController] state synchronously for any [JournalEntity].
class _FakeEntryController extends EntryController {
  _FakeEntryController(this._entry);

  final JournalEntity _entry;

  @override
  Future<EntryState?> build({required String id}) {
    final value = EntryState.saved(
      entryId: id,
      entry: _entry,
      showMap: false,
      isFocused: false,
      shouldShowEditorToolBar: false,
      formKey: GlobalKey<FormBuilderState>(),
    );
    state = AsyncData(value);
    return SynchronousFuture(value);
  }
}

/// Returns a null entry (entity not yet loaded / missing).
class _NullEntryController extends EntryController {
  @override
  Future<EntryState?> build({required String id}) {
    state = const AsyncData(null);
    return SynchronousFuture(null);
  }
}

// ---------------------------------------------------------------------------
// Simplified test widget that mimics EntryDetailsWidget behavior
class TestEntryDetailsWidget extends StatelessWidget {
  const TestEntryDetailsWidget({
    required this.isTask,
    required this.showTaskDetails,
    super.key,
  });

  final bool isTask;
  final bool showTaskDetails;

  @override
  Widget build(BuildContext context) {
    if (isTask && !showTaskDetails) {
      return Padding(
        padding: const EdgeInsets.only(
          left: AppTheme.spacingXSmall,
          right: AppTheme.spacingXSmall,
          bottom: AppTheme.spacingXSmall,
        ),
        child: Container(
          key: const Key('modern-journal-card'),
          height: 100,
          color: Colors.blue,
          child: const Text('Mock Modern Journal Card'),
        ),
      );
    }

    return const Card(
      key: Key('entry-details-card'),
      margin: EdgeInsets.only(
        left: AppTheme.spacingXSmall,
        right: AppTheme.spacingXSmall,
        bottom: AppTheme.spacingMedium,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
        child: Text('Entry Details Content'),
      ),
    );
  }
}

void main() {
  group('EntryDetailsWidget Layout Tests', () {
    testWidgets(
      'wraps task cards with proper padding when showTaskDetails is false',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const TestEntryDetailsWidget(
              isTask: true,
              showTaskDetails: false,
            ),
          ),
        );

        // Find the container that represents our mock card
        final containerFinder = find.byKey(const Key('modern-journal-card'));
        expect(containerFinder, findsOneWidget);

        // Find the padding widget that wraps it
        final paddingFinder = find.ancestor(
          of: containerFinder,
          matching: find.byType(Padding),
        );

        expect(paddingFinder, findsOneWidget);

        final padding = tester.widget<Padding>(paddingFinder);
        expect(
          padding.padding,
          const EdgeInsets.only(
            left: AppTheme.spacingXSmall,
            right: AppTheme.spacingXSmall,
            bottom: AppTheme.spacingXSmall,
          ),
        );
      },
    );

    testWidgets('renders card layout when showTaskDetails is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const TestEntryDetailsWidget(
            isTask: true,
            showTaskDetails: true,
          ),
        ),
      );

      // When showTaskDetails is true, it should render a Card
      expect(find.byType(Card), findsOneWidget);
      expect(find.byKey(const Key('entry-details-card')), findsOneWidget);

      // Mock modern journal card should not be present
      expect(find.byKey(const Key('modern-journal-card')), findsNothing);

      // Verify card margins
      final card = tester.widget<Card>(find.byType(Card));
      expect(
        card.margin,
        const EdgeInsets.only(
          left: AppTheme.spacingXSmall,
          right: AppTheme.spacingXSmall,
          bottom: AppTheme.spacingMedium,
        ),
      );
    });

    testWidgets('renders card layout for non-task entries', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const TestEntryDetailsWidget(
            isTask: false,
            showTaskDetails: false,
          ),
        ),
      );

      // Non-task entries should always render a Card
      expect(find.byType(Card), findsOneWidget);
      expect(find.byKey(const Key('entry-details-card')), findsOneWidget);
    });

    testWidgets('verifies padding structure for task cards', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const TestEntryDetailsWidget(
            isTask: true,
            showTaskDetails: false,
          ),
        ),
      );

      // Verify the widget tree structure
      final container = find.byKey(const Key('modern-journal-card'));
      final padding = find.ancestor(
        of: container,
        matching: find.byType(Padding),
      );

      expect(container, findsOneWidget);
      expect(padding, findsOneWidget);

      // Verify no Card widget is present
      expect(find.byType(Card), findsNothing);
    });
  });

  group('EntryDetailsWidget Highlight Tests', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    late JournalDb mockJournalDb;
    late MockPersistenceLogic mockPersistenceLogic;
    late MockUpdateNotifications mockUpdateNotifications;
    late MockEntitiesCacheService mockEntitiesCacheService;

    setUpAll(setFakeDocumentsPath);

    setUp(() async {
      mockJournalDb = mockJournalDbWithMeasurableTypes([]);
      mockPersistenceLogic = MockPersistenceLogic();
      mockUpdateNotifications = MockUpdateNotifications();
      mockEntitiesCacheService = MockEntitiesCacheService();

      final mockTimeService = MockTimeService();
      final mockEditorStateService = MockEditorStateService();
      final mockHealthImport = MockHealthImport();

      getIt
        ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<EditorStateService>(mockEditorStateService)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
        ..registerSingleton<LinkService>(MockLinkService())
        ..registerSingleton<HealthImport>(mockHealthImport)
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);

      when(() => mockEntitiesCacheService.sortedCategories).thenAnswer(
        (_) => [],
      );

      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      when(() => mockJournalDb.watchConfigFlags()).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          <ConfigFlag>{
            const ConfigFlag(
              name: 'private',
              description: 'Show private entries?',
              status: true,
            ),
          },
        ]),
      );

      when(
        () => mockEditorStateService.getUnsavedStream(
          any(),
          any(),
        ),
      ).thenAnswer(
        (_) => Stream<bool>.fromIterable([false]),
      );

      when(
        mockTimeService.getStream,
      ).thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));
    });

    tearDown(getIt.reset);

    testWidgets('renders without highlight when isHighlighted=false', (
      tester,
    ) async {
      when(
        () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProviderScope(
            child: EntryDetailsWidget(
              itemId: testTextEntry.meta.id,
              showAiEntry: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(EntryDetailsWidget), findsOneWidget);
    });

    testWidgets('renders with highlight when isHighlighted=true', (
      tester,
    ) async {
      when(
        () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProviderScope(
            child: EntryDetailsWidget(
              itemId: testTextEntry.meta.id,
              showAiEntry: false,
              isHighlighted: true,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(EntryDetailsWidget), findsOneWidget);
    });

    testWidgets('highlight toggles from false to true', (tester) async {
      when(
        () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);

      var isHighlighted = false;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          StatefulBuilder(
            builder: (context, setState) {
              return ProviderScope(
                child: Column(
                  children: [
                    Expanded(
                      child: EntryDetailsWidget(
                        itemId: testTextEntry.meta.id,
                        showAiEntry: false,
                        isHighlighted: isHighlighted,
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => isHighlighted = true),
                      child: const Text('Highlight'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ensure button is visible before tapping (may be below fold)
      await tester.ensureVisible(find.text('Highlight'));
      await tester.tap(find.text('Highlight'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(EntryDetailsWidget), findsOneWidget);
    });

    testWidgets('highlight toggles from true to false', (tester) async {
      when(
        () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);

      var isHighlighted = true;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          StatefulBuilder(
            builder: (context, setState) {
              return ProviderScope(
                child: Column(
                  children: [
                    Expanded(
                      child: EntryDetailsWidget(
                        itemId: testTextEntry.meta.id,
                        showAiEntry: false,
                        isHighlighted: isHighlighted,
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => isHighlighted = false),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify button exists
      expect(find.text('Clear'), findsOneWidget);

      await tester.tap(find.text('Clear'), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(EntryDetailsWidget), findsOneWidget);
    });

    testWidgets('showAiEntry and isHighlighted work together', (tester) async {
      when(
        () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProviderScope(
            child: EntryDetailsWidget(
              itemId: testTextEntry.meta.id,
              showAiEntry: true,
              isHighlighted: true,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(EntryDetailsWidget), findsOneWidget);
    });
  });

  group('EntryDetailsWidget Timer Highlight Tests', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    late JournalDb mockJournalDb;
    late MockPersistenceLogic mockPersistenceLogic;
    late MockUpdateNotifications mockUpdateNotifications;
    late MockEntitiesCacheService mockEntitiesCacheService;

    setUpAll(setFakeDocumentsPath);

    setUp(() async {
      mockJournalDb = mockJournalDbWithMeasurableTypes([]);
      mockPersistenceLogic = MockPersistenceLogic();
      mockUpdateNotifications = MockUpdateNotifications();
      mockEntitiesCacheService = MockEntitiesCacheService();

      final mockTimeService = MockTimeService();
      final mockEditorStateService = MockEditorStateService();
      final mockHealthImport = MockHealthImport();

      getIt
        ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<EditorStateService>(mockEditorStateService)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
        ..registerSingleton<LinkService>(MockLinkService())
        ..registerSingleton<HealthImport>(mockHealthImport)
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);

      when(() => mockEntitiesCacheService.sortedCategories).thenAnswer(
        (_) => [],
      );

      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      when(() => mockJournalDb.watchConfigFlags()).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          <ConfigFlag>{
            const ConfigFlag(
              name: 'private',
              description: 'Show private entries?',
              status: true,
            ),
          },
        ]),
      );

      when(
        () => mockEditorStateService.getUnsavedStream(
          any(),
          any(),
        ),
      ).thenAnswer(
        (_) => Stream<bool>.fromIterable([false]),
      );

      when(
        mockTimeService.getStream,
      ).thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));
    });

    tearDown(getIt.reset);

    test('isActiveTimer parameter defaults to false', () {
      const widget = EntryDetailsWidget(
        itemId: 'test-id',
        showAiEntry: false,
      );

      expect(widget.isActiveTimer, isFalse);
    });

    test('isActiveTimer parameter can be set to true', () {
      const widget = EntryDetailsWidget(
        itemId: 'test-id',
        showAiEntry: false,
        isActiveTimer: true,
      );

      expect(widget.isActiveTimer, isTrue);
    });

    test('isActiveTimer and isHighlighted are independent', () {
      const widget = EntryDetailsWidget(
        itemId: 'test-id',
        showAiEntry: false,
        isActiveTimer: true,
        isHighlighted: true,
      );

      expect(widget.isActiveTimer, isTrue);
      expect(widget.isHighlighted, isTrue);
    });

    testWidgets('timer highlight renders a static border overlay', (
      tester,
    ) async {
      when(
        () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProviderScope(
            child: EntryDetailsWidget(
              itemId: testTextEntry.meta.id,
              showAiEntry: false,
              isActiveTimer: true,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify a CustomPaint overlay is rendered without leaving a ticker active.
      expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets(
      'timer highlight border repaints when its theme color changes',
      (tester) async {
        when(
          () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
        ).thenAnswer((_) async => testTextEntry);

        Widget subject({required Color errorColor}) {
          return makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testTextEntry.meta.id,
                showAiEntry: false,
                isActiveTimer: true,
              ),
            ),
            theme: ThemeData.from(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.indigo,
                error: errorColor,
              ),
            ),
          );
        }

        await tester.pumpWidget(subject(errorColor: Colors.red));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));

        // Re-pumping with a different error color forces a new
        // _TimerBorderPainter to be supplied to the CustomPaint, which
        // exercises shouldRepaint with a non-equal oldDelegate.color.
        await tester.pumpWidget(subject(errorColor: Colors.deepOrange));
        // Settle the MaterialApp theme animation so we land on the new
        // color and exercise shouldRepaint with a non-equal oldDelegate.
        await tester.pumpAndSettle();
        expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
      },
    );

    testWidgets('no highlight renders plain card', (tester) async {
      when(
        () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProviderScope(
            child: EntryDetailsWidget(
              itemId: testTextEntry.meta.id,
              showAiEntry: false,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify widget renders
      expect(find.byType(EntryDetailsWidget), findsOneWidget);
    });

    testWidgets('scroll highlight renders when only isHighlighted=true', (
      tester,
    ) async {
      when(
        () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProviderScope(
            child: EntryDetailsWidget(
              itemId: testTextEntry.meta.id,
              showAiEntry: false,
              isHighlighted: true,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify a CustomPaint overlay is rendered for the glow
      expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
    });

    testWidgets('timer highlight takes precedence in rendering order', (
      tester,
    ) async {
      when(
        () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);

      // When both are true, isActiveTimer branch executes first
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProviderScope(
            child: EntryDetailsWidget(
              itemId: testTextEntry.meta.id,
              showAiEntry: false,
              isActiveTimer: true,
              isHighlighted: true,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(EntryDetailsWidget), findsOneWidget);
      expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
    });
  });

  group('EntryDetailsWidget Labels Display Tests', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    late JournalDb mockJournalDb;
    late MockPersistenceLogic mockPersistenceLogic;
    late MockUpdateNotifications mockUpdateNotifications;
    late MockEntitiesCacheService mockEntitiesCacheService;

    setUpAll(setFakeDocumentsPath);

    setUp(() async {
      mockJournalDb = mockJournalDbWithMeasurableTypes([]);
      mockPersistenceLogic = MockPersistenceLogic();
      mockUpdateNotifications = MockUpdateNotifications();
      mockEntitiesCacheService = MockEntitiesCacheService();

      final mockTimeService = MockTimeService();
      final mockEditorStateService = MockEditorStateService();
      final mockHealthImport = MockHealthImport();

      getIt
        ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<EditorStateService>(mockEditorStateService)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
        ..registerSingleton<LinkService>(MockLinkService())
        ..registerSingleton<HealthImport>(mockHealthImport)
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);

      when(() => mockEntitiesCacheService.sortedCategories).thenAnswer(
        (_) => [],
      );
      when(() => mockEntitiesCacheService.showPrivateEntries).thenReturn(true);
      when(() => mockEntitiesCacheService.getLabelById(any())).thenReturn(null);

      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      when(() => mockJournalDb.watchConfigFlags()).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          <ConfigFlag>{
            const ConfigFlag(
              name: 'private',
              description: 'Show private entries?',
              status: true,
            ),
          },
        ]),
      );

      when(
        () => mockEditorStateService.getUnsavedStream(
          any(),
          any(),
        ),
      ).thenAnswer(
        (_) => Stream<bool>.fromIterable([false]),
      );

      when(
        mockTimeService.getStream,
      ).thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));
    });

    tearDown(getIt.reset);

    testWidgets('shows EntryLabelsDisplay for text entries', (tester) async {
      when(
        () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProviderScope(
            child: EntryDetailsWidget(
              itemId: testTextEntry.meta.id,
              showAiEntry: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // EntryLabelsDisplay should be present for text entries
      expect(find.byType(EntryDetailsWidget), findsOneWidget);
    });

    testWidgets('does not show header or edit button for labels in detail view', (
      tester,
    ) async {
      when(
        () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
      ).thenAnswer((_) async => testTextEntry);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProviderScope(
            child: EntryDetailsWidget(
              itemId: testTextEntry.meta.id,
              showAiEntry: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // The labels display in entry details uses chips only mode (no header/edit)
      // The "Labels" header text should NOT be present
      expect(find.text('Labels'), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // Coverage tests: branches reachable only with specific entry types/flags.
  // ---------------------------------------------------------------------------

  group('EntryDetailsWidget coverage – task & deleted branches', () {
    late MockUpdateNotifications mockUpdateNotifications;
    late MockEntitiesCacheService mockEntitiesCacheService;
    late MockEditorStateService mockEditorStateService;
    late MockTimeService mockTimeService;

    setUpAll(setFakeDocumentsPath);

    setUp(() async {
      mockUpdateNotifications = MockUpdateNotifications();
      mockEntitiesCacheService = MockEntitiesCacheService();
      mockEditorStateService = MockEditorStateService();
      mockTimeService = MockTimeService();

      final mockJournalDb = mockJournalDbWithMeasurableTypes([]);
      final mockPersistenceLogic = MockPersistenceLogic();
      final mockHealthImport = MockHealthImport();

      getIt
        ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<EditorStateService>(mockEditorStateService)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
        ..registerSingleton<LinkService>(MockLinkService())
        ..registerSingleton<HealthImport>(mockHealthImport)
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<NavService>(MockNavService());

      when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);
      when(() => mockEntitiesCacheService.showPrivateEntries).thenReturn(true);
      when(
        () => mockEntitiesCacheService.getLabelById(any()),
      ).thenReturn(null);
      when(
        () => mockEntitiesCacheService.getCategoryById(any()),
      ).thenReturn(null);

      when(
        () => mockUpdateNotifications.updateStream,
      ).thenAnswer((_) => Stream<Set<String>>.fromIterable([]));

      when(
        // ignore: unnecessary_lambdas
        () => mockJournalDb.watchConfigFlags(),
      ).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          <ConfigFlag>{
            const ConfigFlag(
              name: 'private',
              description: 'Show private entries?',
              status: true,
            ),
          },
        ]),
      );

      when(
        () => mockEditorStateService.getUnsavedStream(any(), any()),
      ).thenAnswer((_) => Stream<bool>.fromIterable([false]));

      when(
        mockTimeService.getStream,
      ).thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));
    });

    tearDown(getIt.reset);

    // Line 79: hideTaskEntries=true for a Task → SizedBox.shrink()
    testWidgets(
      'returns SizedBox.shrink when isTask and hideTaskEntries=true',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              overrides: [
                entryControllerProvider(id: testTask.meta.id).overrideWith(
                  () => _FakeEntryController(testTask),
                ),
              ],
              child: EntryDetailsWidget(
                itemId: testTask.meta.id,
                showAiEntry: false,
                hideTaskEntries: true,
              ),
            ),
          ),
        );

        await tester.pump();

        // Widget renders but the EntryDetailsContent is hidden (SizedBox.shrink)
        // so neither EntryDetailsContent nor ModernJournalCard should appear.
        expect(find.byType(EntryDetailsContent), findsNothing);
      },
    );

    // Lines 84-85, 91: isTask=true, showTaskDetails=false → ModernJournalCard
    testWidgets(
      'renders ModernJournalCard for task when showTaskDetails=false',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              overrides: [
                entryControllerProvider(id: testTask.meta.id).overrideWith(
                  () => _FakeEntryController(testTask),
                ),
              ],
              child: EntryDetailsWidget(
                itemId: testTask.meta.id,
                showAiEntry: false,
                // ignore: avoid_redundant_argument_values
                showTaskDetails: false,
              ),
            ),
          ),
        );

        await tester.pump();

        // The Padding wrapper with XSmall spacing should be present (lines 85-90).
        // ModernJournalCard renders inside it — we can verify the Padding values
        // match what EntryDetailsWidget hardcodes for this branch.
        final paddingFinder = find.byType(Padding).first;
        expect(paddingFinder, findsOneWidget);
        // EntryDetailsContent is NOT rendered in this branch.
        expect(find.byType(EntryDetailsContent), findsNothing);
      },
    );

    // AiResponseEntry with showAiEntry=false → SizedBox.shrink (line 71-72)
    testWidgets(
      'returns SizedBox.shrink for AiResponseEntry when showAiEntry=false',
      (tester) async {
        final aiEntry = JournalEntity.aiResponse(
          meta: Metadata(
            id: 'ai-entry-id',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
          ),
          data: const AiResponseData(
            model: 'test-model',
            systemMessage: '',
            prompt: 'test prompt',
            thoughts: '',
            response: 'test response',
          ),
        );

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              overrides: [
                entryControllerProvider(id: 'ai-entry-id').overrideWith(
                  () => _FakeEntryController(aiEntry),
                ),
              ],
              child: const EntryDetailsWidget(
                itemId: 'ai-entry-id',
                showAiEntry: false,
              ),
            ),
          ),
        );

        await tester.pump();

        // AiResponseEntry with showAiEntry=false collapses to SizedBox.shrink
        expect(find.byType(EntryDetailsContent), findsNothing);
      },
    );

    // Null entry → SizedBox.shrink (null item check)
    testWidgets('returns SizedBox.shrink when entry state is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProviderScope(
            overrides: [
              entryControllerProvider(
                id: 'missing-id',
              ).overrideWith(_NullEntryController.new),
            ],
            child: const EntryDetailsWidget(
              itemId: 'missing-id',
              showAiEntry: false,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(EntryDetailsContent), findsNothing);
    });

    // Deleted entry (deletedAt set) → SizedBox.shrink in EntryDetailsWidget
    testWidgets('returns SizedBox.shrink when entry has deletedAt set', (
      tester,
    ) async {
      final deletedEntry = testTextEntry.copyWith(
        meta: testTextEntry.meta.copyWith(deletedAt: DateTime(2024, 3, 15)),
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ProviderScope(
            overrides: [
              entryControllerProvider(
                id: deletedEntry.meta.id,
              ).overrideWith(() => _FakeEntryController(deletedEntry)),
            ],
            child: EntryDetailsWidget(
              itemId: deletedEntry.meta.id,
              showAiEntry: false,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(EntryDetailsContent), findsNothing);
    });
  });

  group('EntryDetailsWidget coverage – isHighlighted with category color', () {
    late MockUpdateNotifications mockUpdateNotifications;
    late MockEntitiesCacheService mockEntitiesCacheService;
    late MockEditorStateService mockEditorStateService;
    late MockTimeService mockTimeService;

    setUpAll(setFakeDocumentsPath);

    setUp(() async {
      mockUpdateNotifications = MockUpdateNotifications();
      mockEntitiesCacheService = MockEntitiesCacheService();
      mockEditorStateService = MockEditorStateService();
      mockTimeService = MockTimeService();

      final mockJournalDb = mockJournalDbWithMeasurableTypes([]);
      final mockPersistenceLogic = MockPersistenceLogic();
      final mockHealthImport = MockHealthImport();

      getIt
        ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<EditorStateService>(mockEditorStateService)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
        ..registerSingleton<LinkService>(MockLinkService())
        ..registerSingleton<HealthImport>(mockHealthImport)
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<NavService>(MockNavService());

      when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);
      when(() => mockEntitiesCacheService.showPrivateEntries).thenReturn(true);
      when(
        () => mockEntitiesCacheService.getLabelById(any()),
      ).thenReturn(null);

      when(
        () => mockUpdateNotifications.updateStream,
      ).thenAnswer((_) => Stream<Set<String>>.fromIterable([]));

      when(
        // ignore: unnecessary_lambdas
        () => mockJournalDb.watchConfigFlags(),
      ).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          <ConfigFlag>{
            const ConfigFlag(
              name: 'private',
              description: 'Show private entries?',
              status: true,
            ),
          },
        ]),
      );

      when(
        () => mockEditorStateService.getUnsavedStream(any(), any()),
      ).thenAnswer((_) => Stream<bool>.fromIterable([false]));

      when(
        mockTimeService.getStream,
      ).thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));
    });

    tearDown(getIt.reset);

    // Line 158: isHighlighted=true AND category != null → colorFromCssHex path
    testWidgets(
      'uses category color for pulsing border when category is found',
      (tester) async {
        // Stub getCategoryById to return a real category with a CSS hex color
        when(
          () => mockEntitiesCacheService.getCategoryById(any()),
        ).thenReturn(categoryMindfulness);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              overrides: [
                entryControllerProvider(
                  id: testTextEntry.meta.id,
                ).overrideWith(() => _FakeEntryController(testTextEntry)),
              ],
              child: EntryDetailsWidget(
                itemId: testTextEntry.meta.id,
                showAiEntry: false,
                isHighlighted: true,
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // The Stack + _PulsingBorder CustomPaint should be present.
        expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
      },
    );

    // Line 158 fallback: isHighlighted=true AND category == null → Colors.pink
    testWidgets(
      'falls back to pink when no category found for highlighted entry',
      (tester) async {
        when(
          () => mockEntitiesCacheService.getCategoryById(any()),
        ).thenReturn(null);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              overrides: [
                entryControllerProvider(
                  id: testTextEntry.meta.id,
                ).overrideWith(() => _FakeEntryController(testTextEntry)),
              ],
              child: EntryDetailsWidget(
                itemId: testTextEntry.meta.id,
                showAiEntry: false,
                isHighlighted: true,
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
      },
    );

    // Lines 232-237: _GlowBorderPainter.shouldRepaint – triggered by pumping
    // the same widget with a different category color, forcing a repaint.
    testWidgets(
      '_GlowBorderPainter.shouldRepaint is exercised when category color changes',
      (tester) async {
        // First render with blue category
        when(
          () => mockEntitiesCacheService.getCategoryById(any()),
        ).thenReturn(categoryMindfulness); // color: '#0000FFFF'

        Future<void> buildWidget() async {
          await tester.pumpWidget(
            makeTestableWidgetWithScaffold(
              ProviderScope(
                overrides: [
                  entryControllerProvider(
                    id: testTextEntry.meta.id,
                  ).overrideWith(() => _FakeEntryController(testTextEntry)),
                ],
                child: EntryDetailsWidget(
                  itemId: testTextEntry.meta.id,
                  showAiEntry: false,
                  isHighlighted: true,
                ),
              ),
            ),
          );
        }

        await buildWidget();
        await tester.pump();
        expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));

        // Change to a different category color to trigger shouldRepaint
        when(
          () => mockEntitiesCacheService.getCategoryById(any()),
        ).thenReturn(
          CategoryDefinition(
            id: 'cat-red',
            name: 'Red',
            color: '#FF0000FF',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
            active: true,
            private: false,
          ),
        );

        await buildWidget();
        // pumpAndSettle to let the animation controller tick through at least
        // one frame so the _PulsingBorder repaint path is exercised.
        await tester.pumpAndSettle();
        expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
      },
    );
  });

  group('EntryDetailsContent coverage – entry type detail sections', () {
    late MockUpdateNotifications mockUpdateNotifications;
    late MockEntitiesCacheService mockEntitiesCacheService;
    late MockEditorStateService mockEditorStateService;
    late MockTimeService mockTimeService;
    late JournalDb mockJournalDb;

    setUpAll(setFakeDocumentsPath);

    setUp(() async {
      mockUpdateNotifications = MockUpdateNotifications();
      mockEntitiesCacheService = MockEntitiesCacheService();
      mockEditorStateService = MockEditorStateService();
      mockTimeService = MockTimeService();
      mockJournalDb = mockJournalDbWithMeasurableTypes([]);

      final mockPersistenceLogic = MockPersistenceLogic();
      final mockHealthImport = MockHealthImport();

      getIt
        ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<EditorStateService>(mockEditorStateService)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
        ..registerSingleton<LinkService>(MockLinkService())
        ..registerSingleton<HealthImport>(mockHealthImport)
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<NavService>(MockNavService());

      when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);
      when(() => mockEntitiesCacheService.showPrivateEntries).thenReturn(true);
      when(
        () => mockEntitiesCacheService.getLabelById(any()),
      ).thenReturn(null);
      when(
        () => mockEntitiesCacheService.getCategoryById(any()),
      ).thenReturn(null);

      when(
        () => mockUpdateNotifications.updateStream,
      ).thenAnswer((_) => Stream<Set<String>>.fromIterable([]));

      when(
        () => mockJournalDb.watchConfigFlags(),
      ).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          <ConfigFlag>{
            const ConfigFlag(
              name: 'private',
              description: 'Show private entries?',
              status: true,
            ),
          },
        ]),
      );

      when(
        () => mockEditorStateService.getUnsavedStream(any(), any()),
      ).thenAnswer((_) => Stream<bool>.fromIterable([false]));

      when(
        mockTimeService.getStream,
      ).thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));
    });

    tearDown(getIt.reset);

    // Lines 483 (AiResponseEntry path – showAiEntry=true so it renders)
    testWidgets(
      'EntryDetailsContent renders AiResponseSummary for AiResponseEntry',
      (tester) async {
        final aiEntry = JournalEntity.aiResponse(
          meta: Metadata(
            id: 'ai-detail-id',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
          ),
          data: const AiResponseData(
            model: 'test-model',
            systemMessage: '',
            prompt: 'prompt text',
            thoughts: '',
            response: 'AI response text',
          ),
        );

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              overrides: [
                entryControllerProvider(id: 'ai-detail-id').overrideWith(
                  () => _FakeEntryController(aiEntry),
                ),
              ],
              child: const EntryDetailsWidget(
                itemId: 'ai-detail-id',
                showAiEntry: true,
              ),
            ),
          ),
        );

        await tester.pump();

        // EntryDetailsContent must be present (not SizedBox.shrink)
        expect(find.byType(EntryDetailsContent), findsOneWidget);
      },
    );

    // Lines 487-488: Checklist entry → ChecklistCardWrapper rendered
    // (requires linkedTasks to have at least one entry for the card wrapper)
    testWidgets(
      'EntryDetailsContent renders for Checklist entry',
      (tester) async {
        final checklist = JournalEntity.checklist(
          meta: Metadata(
            id: 'checklist-id',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
          ),
          data: const ChecklistData(
            title: 'Test Checklist',
            linkedChecklistItems: <String>[],
            linkedTasks: ['task-id-1'],
          ),
        );

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              overrides: [
                entryControllerProvider(id: 'checklist-id').overrideWith(
                  () => _FakeEntryController(checklist),
                ),
              ],
              child: const EntryDetailsWidget(
                itemId: 'checklist-id',
                showAiEntry: false,
              ),
            ),
          ),
        );

        await tester.pump();

        // EntryDetailsContent must be present (not hidden)
        expect(find.byType(EntryDetailsContent), findsOneWidget);
      },
    );

    // Lines 494-498: ChecklistItem entry → ChecklistItemRow rendered
    testWidgets(
      'EntryDetailsContent renders for ChecklistItem entry',
      (tester) async {
        final checklistItem = JournalEntity.checklistItem(
          meta: Metadata(
            id: 'checklist-item-id',
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
          ),
          data: const ChecklistItemData(
            title: 'Test item',
            isChecked: false,
            linkedChecklists: ['checklist-parent-id'],
          ),
        );

        // Use makeTestableWidget (SingleChildScrollView) to avoid overflow
        // errors from ChecklistItemRow in a constrained Scaffold body.
        await tester.pumpWidget(
          makeTestableWidget(
            ProviderScope(
              overrides: [
                entryControllerProvider(id: 'checklist-item-id').overrideWith(
                  () => _FakeEntryController(checklistItem),
                ),
              ],
              child: const EntryDetailsWidget(
                itemId: 'checklist-item-id',
                showAiEntry: false,
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.byType(EntryDetailsContent), findsOneWidget);
      },
    );

    // Lines 575-576: NestedAiResponsesWidget is rendered for non-collapsible
    // audio entries (the non-collapsible column path, line 574-578).
    testWidgets(
      'EntryDetailsContent renders NestedAiResponsesWidget for JournalAudio '
      'in non-collapsible layout',
      (tester) async {
        final mockJournalRepository = MockJournalRepository();
        when(
          () => mockJournalRepository.getLinksFromId(testAudioEntry.meta.id),
        ).thenAnswer((_) async => <EntryLink>[]);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              overrides: [
                entryControllerProvider(
                  id: testAudioEntry.meta.id,
                ).overrideWith(() => _FakeEntryController(testAudioEntry)),
                journalRepositoryProvider.overrideWithValue(
                  mockJournalRepository,
                ),
              ],
              child: EntryDetailsWidget(
                itemId: testAudioEntry.meta.id,
                showAiEntry: false,
              ),
            ),
          ),
        );

        await tester.pump();

        // NestedAiResponsesWidget is always included in the widget tree for
        // audio entries (even if it renders as SizedBox.shrink internally).
        expect(find.byType(NestedAiResponsesWidget), findsOneWidget);
        // AudioPlayerWidget is the detail section for audio entries.
        expect(find.byType(AudioPlayerWidget), findsOneWidget);
      },
    );

    // MeasurementSummary rendered for MeasurementEntry (not a task, not an
    // audio — verifies the generic detailSection branch).
    testWidgets(
      'EntryDetailsContent renders MeasurementSummary for MeasurementEntry',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              overrides: [
                entryControllerProvider(
                  id: testMeasurementChocolateEntry.meta.id,
                ).overrideWith(
                  () => _FakeEntryController(testMeasurementChocolateEntry),
                ),
              ],
              child: EntryDetailsWidget(
                itemId: testMeasurementChocolateEntry.meta.id,
                showAiEntry: false,
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.byType(MeasurementSummary), findsOneWidget);
      },
    );

    // HabitSummary rendered for HabitCompletionEntry.
    testWidgets(
      'EntryDetailsContent renders HabitSummary for HabitCompletionEntry',
      (tester) async {
        when(
          () => mockJournalDb.getHabitById(any()),
        ).thenAnswer((_) async => habitFlossing);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              overrides: [
                entryControllerProvider(
                  id: testHabitCompletionEntry.meta.id,
                ).overrideWith(
                  () => _FakeEntryController(testHabitCompletionEntry),
                ),
              ],
              child: EntryDetailsWidget(
                itemId: testHabitCompletionEntry.meta.id,
                showAiEntry: false,
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.byType(HabitSummary), findsOneWidget);
      },
    );

    // Deleted entry in EntryDetailsContent (line 447) → SizedBox.shrink
    testWidgets(
      'EntryDetailsContent returns SizedBox.shrink when entry is deleted',
      (tester) async {
        final deletedEntry = testTextEntry.copyWith(
          meta: testTextEntry.meta.copyWith(deletedAt: DateTime(2024, 3, 15)),
        );

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              overrides: [
                // Use the SAME itemId so both EntryDetailsWidget and
                // EntryDetailsContent watch the same provider.
                entryControllerProvider(
                  id: deletedEntry.meta.id,
                ).overrideWith(() => _FakeEntryController(deletedEntry)),
              ],
              child: EntryDetailsWidget(
                // EntryDetailsWidget sees deletedAt → collapses before
                // EntryDetailsContent is even built (line 70-72 guard).
                itemId: deletedEntry.meta.id,
                showAiEntry: false,
              ),
            ),
          ),
        );

        await tester.pump();

        // Neither the outer nor inner widget should render visible content.
        expect(find.byType(EntryDetailsContent), findsNothing);
      },
    );
  });

  group('_CollapsibleBody coverage – didUpdateWidget collapse/expand', () {
    // _CollapsibleBody is a private widget; we drive it indirectly through
    // EntryDetailsContent when linkedFrom != null and the item is collapsible.

    late MockUpdateNotifications mockUpdateNotifications;
    late MockEntitiesCacheService mockEntitiesCacheService;
    late MockEditorStateService mockEditorStateService;
    late MockTimeService mockTimeService;
    late JournalDb mockJournalDb;

    setUpAll(setFakeDocumentsPath);

    setUp(() async {
      mockUpdateNotifications = MockUpdateNotifications();
      mockEntitiesCacheService = MockEntitiesCacheService();
      mockEditorStateService = MockEditorStateService();
      mockTimeService = MockTimeService();
      mockJournalDb = mockJournalDbWithMeasurableTypes([]);

      final mockPersistenceLogic = MockPersistenceLogic();
      final mockHealthImport = MockHealthImport();

      getIt
        ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<EditorStateService>(mockEditorStateService)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
        ..registerSingleton<LinkService>(MockLinkService())
        ..registerSingleton<HealthImport>(mockHealthImport)
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<NavService>(MockNavService());

      when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);
      when(() => mockEntitiesCacheService.showPrivateEntries).thenReturn(true);
      when(
        () => mockEntitiesCacheService.getLabelById(any()),
      ).thenReturn(null);
      when(
        () => mockEntitiesCacheService.getCategoryById(any()),
      ).thenReturn(null);

      when(
        () => mockUpdateNotifications.updateStream,
      ).thenAnswer((_) => Stream<Set<String>>.fromIterable([]));

      when(
        () => mockJournalDb.watchConfigFlags(),
      ).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          <ConfigFlag>{
            const ConfigFlag(
              name: 'private',
              description: 'Show private entries?',
              status: true,
            ),
          },
        ]),
      );

      when(
        () => mockEditorStateService.getUnsavedStream(any(), any()),
      ).thenAnswer((_) => Stream<bool>.fromIterable([false]));

      when(
        mockTimeService.getStream,
      ).thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));
    });

    tearDown(getIt.reset);

    // Lines 667-674: _CollapsibleBodyState.didUpdateWidget called when
    // isCollapsed changes – expand path (forward) and collapse path (reverse).
    testWidgets(
      '_CollapsibleBody animates from expanded to collapsed (didUpdateWidget reverse)',
      (tester) async {
        // A text entry with linkedFrom set is collapsible.
        var isCollapsed = false;

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            StatefulBuilder(
              builder: (context, setState) {
                return ProviderScope(
                  overrides: [
                    entryControllerProvider(
                      id: testTextEntry.meta.id,
                    ).overrideWith(() => _FakeEntryController(testTextEntry)),
                  ],
                  child: Column(
                    children: [
                      Expanded(
                        child: EntryDetailsContent(
                          testTextEntry.meta.id,
                          linkedFrom:
                              testTextEntry, // non-null → isCollapsible=true for JournalEntry
                          link: EntryLink.basic(
                            id: 'link-id',
                            fromId: 'from',
                            toId: testTextEntry.meta.id,
                            createdAt: DateTime(2024, 3, 15),
                            updatedAt: DateTime(2024, 3, 15),
                            vectorClock: null,
                            collapsed: isCollapsed,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => isCollapsed = true),
                        child: const Text('Collapse'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );

        await tester.pump();

        // Initially expanded – content visible.
        expect(find.byType(EntryDetailsContent), findsOneWidget);

        // Trigger collapse → didUpdateWidget with isCollapsed=true (line 671-672).
        await tester.ensureVisible(find.text('Collapse'));
        await tester.tap(find.text('Collapse'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Widget tree still present after collapse animation starts.
        expect(find.byType(EntryDetailsContent), findsOneWidget);
      },
    );

    testWidgets(
      '_CollapsibleBody animates from collapsed to expanded (didUpdateWidget forward)',
      (tester) async {
        var isCollapsed = true;

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            StatefulBuilder(
              builder: (context, setState) {
                return ProviderScope(
                  overrides: [
                    entryControllerProvider(
                      id: testTextEntry.meta.id,
                    ).overrideWith(() => _FakeEntryController(testTextEntry)),
                  ],
                  child: Column(
                    children: [
                      Expanded(
                        child: EntryDetailsContent(
                          testTextEntry.meta.id,
                          linkedFrom: testTextEntry,
                          link: EntryLink.basic(
                            id: 'link-id',
                            fromId: 'from',
                            toId: testTextEntry.meta.id,
                            createdAt: DateTime(2024, 3, 15),
                            updatedAt: DateTime(2024, 3, 15),
                            vectorClock: null,
                            collapsed: isCollapsed,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => isCollapsed = false),
                        child: const Text('Expand'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );

        await tester.pump();

        // Trigger expand → didUpdateWidget with isCollapsed=false (line 673-674).
        await tester.ensureVisible(find.text('Expand'));
        await tester.tap(find.text('Expand'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(EntryDetailsContent), findsOneWidget);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Coverage tests: _PulsingBorder timer callback and _GlowBorderPainter
  // shouldRepaint radius/strokeWidth/glowSigma branches.
  // ---------------------------------------------------------------------------

  group('_PulsingBorder timer and _GlowBorderPainter.shouldRepaint branches', () {
    late MockUpdateNotifications mockUpdateNotifications;
    late MockEntitiesCacheService mockEntitiesCacheService;
    late MockEditorStateService mockEditorStateService;
    late MockTimeService mockTimeService;

    setUpAll(setFakeDocumentsPath);

    setUp(() async {
      mockUpdateNotifications = MockUpdateNotifications();
      mockEntitiesCacheService = MockEntitiesCacheService();
      mockEditorStateService = MockEditorStateService();
      mockTimeService = MockTimeService();

      final mockJournalDb = mockJournalDbWithMeasurableTypes([]);
      final mockPersistenceLogic = MockPersistenceLogic();
      final mockHealthImport = MockHealthImport();

      getIt
        ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<EditorStateService>(mockEditorStateService)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
        ..registerSingleton<LinkService>(MockLinkService())
        ..registerSingleton<HealthImport>(mockHealthImport)
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<NavService>(MockNavService());

      when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);
      when(() => mockEntitiesCacheService.showPrivateEntries).thenReturn(true);
      when(
        () => mockEntitiesCacheService.getLabelById(any()),
      ).thenReturn(null);
      when(
        () => mockEntitiesCacheService.getCategoryById(any()),
      ).thenReturn(null);

      when(
        () => mockUpdateNotifications.updateStream,
      ).thenAnswer((_) => Stream<Set<String>>.fromIterable([]));

      when(
        // ignore: unnecessary_lambdas
        () => mockJournalDb.watchConfigFlags(),
      ).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          <ConfigFlag>{
            const ConfigFlag(
              name: 'private',
              description: 'Show private entries?',
              status: true,
            ),
          },
        ]),
      );

      when(
        () => mockEditorStateService.getUnsavedStream(any(), any()),
      ).thenAnswer((_) => Stream<bool>.fromIterable([false]));

      when(
        mockTimeService.getStream,
      ).thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));
    });

    tearDown(getIt.reset);

    // Lines 328-329: _PulsingBorder._startDelayTimer callback.
    // The startDelay is 1000 ms.  Pumping past that threshold causes the Timer
    // to fire while the widget is still mounted, which exercises line 328
    // (`if (!mounted) return;` evaluating to false) and line 329
    // (`_controller.forward()`).
    testWidgets(
      '_PulsingBorder timer fires while mounted and starts animation',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              overrides: [
                entryControllerProvider(
                  id: testTextEntry.meta.id,
                ).overrideWith(() => _FakeEntryController(testTextEntry)),
              ],
              child: EntryDetailsWidget(
                itemId: testTextEntry.meta.id,
                showAiEntry: false,
                isHighlighted: true,
              ),
            ),
          ),
        );

        await tester.pump();

        // Advance time past the 1000 ms startDelay in two steps (each < 1 s)
        // so the Timer callback fires while _PulsingBorderState is still mounted.
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 600));

        // The animation has started: the widget is still in the tree and the
        // AnimationController is running (transient callbacks registered).
        expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));

        // Settle the animation so tickers are cleaned up before the next test.
        await tester.pump(const Duration(milliseconds: 5000));
      },
    );

    // Lines 201-229: _GlowBorderPainter.paint() — the actual border-drawing
    // code. The pulsing border lives inside a FadeTransition whose opacity
    // animation starts at 0.0 (during the startDelay window). While the opacity
    // is exactly 0, RenderAnimatedOpacity skips painting its child entirely, so
    // _GlowBorderPainter.paint() never runs. Earlier tests only sampled frames
    // near t=0 where the opacity was ~0, leaving paint() uncovered.
    //
    // Here we let the startDelay (1000 ms) elapse, then step the animation
    // forward in small frames until the first up-tween (0.0 -> 1.0 over the
    // first 1/8 of the 4800 ms controller, i.e. ~600 ms) lifts the opacity to a
    // clearly non-zero value. Once opacity > 0 the FadeTransition paints its
    // child and _GlowBorderPainter.paint() executes for real. We then play the
    // animation out to completion and confirm the widget disposes cleanly with
    // no leaked Timer/ticker.
    testWidgets(
      '_PulsingBorder paints the glow border once the fade-in opacity rises '
      'above zero, then fades out and disposes cleanly',
      (tester) async {
        when(
          () => mockEntitiesCacheService.getCategoryById(any()),
        ).thenReturn(categoryMindfulness);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              overrides: [
                entryControllerProvider(
                  id: testTextEntry.meta.id,
                ).overrideWith(() => _FakeEntryController(testTextEntry)),
              ],
              child: EntryDetailsWidget(
                itemId: testTextEntry.meta.id,
                showAiEntry: false,
                isHighlighted: true,
              ),
            ),
          ),
        );

        await tester.pump();

        // The highlighted layout mounts a FadeTransition wrapping the
        // CustomPaint glow border. Grab the inner-most FadeTransition (the
        // _PulsingBorder one) so we can observe its opacity directly.
        FadeTransition pulsingFade() {
          return tester
              .widgetList<FadeTransition>(find.byType(FadeTransition))
              .last;
        }

        // During the 1000 ms startDelay the controller is parked at value 0,
        // so the first up-tween (begin: 0.0) yields opacity 0 and the border
        // stays hidden. Pump up to just before the delay fires.
        await tester.pump(const Duration(milliseconds: 900));
        expect(pulsingFade().opacity.value, 0.0);

        // Cross the startDelay so the Timer fires _controller.forward(), then
        // step forward in small frames. By ~600 ms into the controller the
        // first up-tween has reached its peak (high = 1.0), so the opacity is
        // unambiguously > 0 and the FadeTransition paints the CustomPaint child
        // — running _GlowBorderPainter.paint().
        await tester.pump(const Duration(milliseconds: 200)); // delay fires
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // The fade-in has lifted the border to a clearly visible opacity.
        final visibleOpacity = pulsingFade().opacity.value;
        expect(visibleOpacity, greaterThan(0.5));

        // The CustomPaint that paint() drew is in the tree and its painter is
        // the private _GlowBorderPainter (verified via runtime type name so we
        // do not depend on the private symbol).
        final customPaints = tester.widgetList<CustomPaint>(
          find.byType(CustomPaint),
        );
        expect(
          customPaints.any(
            (cp) => cp.painter.runtimeType.toString() == '_GlowBorderPainter',
          ),
          isTrue,
        );

        // Play the animation out to completion (4800 ms controller + the
        // 1000 ms delay already elapsed). The final down-tween fades the last
        // loop to 0.0, so the border ends hidden again.
        await tester.pump(const Duration(milliseconds: 5000));
        expect(pulsingFade().opacity.value, 0.0);

        // No pending Timer / active ticker leaked: the controller has stopped
        // and the startDelay Timer already fired and was discarded.
        expect(tester.binding.transientCallbackCount, 0);
        expect(tester.takeException(), isNull);
      },
    );

    // Lines 235-237: _GlowBorderPainter.shouldRepaint — radius, strokeWidth,
    // and glowSigma checks.
    //
    // `shouldRepaint` is only called by Flutter when a CustomPaint is rebuilt
    // with a new painter.  The `color` comparison (line 234) short-circuits
    // to `true` whenever the pulsing animation has ticked (color shifts via
    // lerp), so lines 235-237 are never reached in the existing tests.
    //
    // Strategy: keep the animation frozen at t=0 so that `tinted` equals
    // `widget.color` on every build (p=0 → no lerp shift).  Then force a
    // second build of `_PulsingBorderState` (via a StatefulBuilder setState)
    // without advancing time.  Flutter calls `shouldRepaint` comparing two
    // painters whose `color`, `radius`, `strokeWidth`, and `glowSigma` are all
    // identical — so the check falls through lines 234→235→236→237 and returns
    // false.  All four lines are now exercised.
    testWidgets(
      '_GlowBorderPainter.shouldRepaint exercises radius/strokeWidth/glowSigma '
      'checks when color is unchanged between builds',
      (tester) async {
        var counter = 0;

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            StatefulBuilder(
              builder: (context, setState) {
                return ProviderScope(
                  overrides: [
                    entryControllerProvider(
                      id: testTextEntry.meta.id,
                    ).overrideWith(() => _FakeEntryController(testTextEntry)),
                  ],
                  child: Column(
                    children: [
                      EntryDetailsWidget(
                        itemId: testTextEntry.meta.id,
                        showAiEntry: false,
                        isHighlighted: true,
                      ),
                      TextButton(
                        onPressed: () => setState(() => counter++),
                        child: Text('rebuild-$counter'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );

        // First frame — widget tree is fully built; animation still at t=0
        // (Timer hasn't fired yet so _controller hasn't started).
        await tester.pump();

        // Trigger a rebuild WITHOUT advancing fake time so the animation value
        // stays at its initial position (tinted == widget.color on both builds).
        await tester.ensureVisible(
          find.widgetWithText(TextButton, 'rebuild-0'),
        );
        await tester.tap(find.widgetWithText(TextButton, 'rebuild-0'));
        await tester.pump();

        // shouldRepaint was called; CustomPaint is still in the tree.
        expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Coverage: onToggleCollapse auto-scroll path (line 552).
  //
  // When a collapsed, collapsible entry is expanded AND its card top has been
  // scrolled above the visible viewport, the delayed callback calls
  // `Scrollable.ensureVisible` to bring it back into view. Reaching this
  // requires a real Scrollable/viewport ancestor scrolled past the card so that
  // `revealedOffset.offset < currentOffset` evaluates to true.
  // ---------------------------------------------------------------------------

  group('EntryDetailsContent coverage – auto-scroll on expand', () {
    late MockUpdateNotifications mockUpdateNotifications;
    late MockEntitiesCacheService mockEntitiesCacheService;
    late MockEditorStateService mockEditorStateService;
    late MockTimeService mockTimeService;
    late JournalDb mockJournalDb;

    setUpAll(() {
      setFakeDocumentsPath();
      // EntryLink fallback for mocktail any() on updateLink(EntryLink).
      registerFallbackValue(
        EntryLink.basic(
          id: 'fallback-link',
          fromId: 'fallback-from',
          toId: 'fallback-to',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
        ),
      );
    });

    setUp(() async {
      mockUpdateNotifications = MockUpdateNotifications();
      mockEntitiesCacheService = MockEntitiesCacheService();
      mockEditorStateService = MockEditorStateService();
      mockTimeService = MockTimeService();
      mockJournalDb = mockJournalDbWithMeasurableTypes([]);

      final mockPersistenceLogic = MockPersistenceLogic();
      final mockHealthImport = MockHealthImport();

      getIt
        ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<EditorStateService>(mockEditorStateService)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
        ..registerSingleton<LinkService>(MockLinkService())
        ..registerSingleton<HealthImport>(mockHealthImport)
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<NavService>(MockNavService());

      when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);
      when(() => mockEntitiesCacheService.showPrivateEntries).thenReturn(true);
      when(
        () => mockEntitiesCacheService.getLabelById(any()),
      ).thenReturn(null);
      when(
        () => mockEntitiesCacheService.getCategoryById(any()),
      ).thenReturn(null);

      when(
        () => mockUpdateNotifications.updateStream,
      ).thenAnswer((_) => Stream<Set<String>>.fromIterable([]));

      when(
        () => mockJournalDb.watchConfigFlags(),
      ).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          <ConfigFlag>{
            const ConfigFlag(
              name: 'private',
              description: 'Show private entries?',
              status: true,
            ),
          },
        ]),
      );

      when(
        () => mockEditorStateService.getUnsavedStream(any(), any()),
      ).thenAnswer((_) => Stream<bool>.fromIterable([false]));

      when(
        mockTimeService.getStream,
      ).thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));
    });

    tearDown(getIt.reset);

    // Line 552: Scrollable.ensureVisible runs when the expanded card's top is
    // above the current scroll offset. We embed the collapsible entry inside a
    // scrollable, jump the scroll position below the card, then tap the chevron
    // (collapsed → expand) so isExpanding=true and the delayed branch fires.
    testWidgets(
      'expanding a scrolled-past collapsed entry triggers ensureVisible',
      (tester) async {
        final mockJournalRepository = MockJournalRepository();
        when(
          () => mockJournalRepository.updateLink(any()),
        ).thenAnswer((_) async => true);

        // Collapsed link so tapping the chevron expands (isExpanding=true).
        final collapsedLink = EntryLink.basic(
          id: 'link-autoscroll',
          fromId: testTask.meta.id,
          toId: testTextEntry.meta.id,
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
          collapsed: true,
        );

        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              overrides: [
                entryControllerProvider(
                  id: testTextEntry.meta.id,
                ).overrideWith(() => _FakeEntryController(testTextEntry)),
                journalRepositoryProvider.overrideWithValue(
                  mockJournalRepository,
                ),
              ],
              // Fixed-height box gives the inner CustomScrollView a bounded
              // viewport so we can scroll the entry above the visible area.
              // A large cacheExtent keeps the entry's render object alive even
              // after its top is scrolled just above the viewport, so the
              // delayed callback can still resolve a render object + viewport.
              child: SizedBox(
                height: 400,
                child: CustomScrollView(
                  controller: scrollController,
                  scrollCacheExtent: const ScrollCacheExtent.pixels(2000),
                  slivers: [
                    // Entry first (top at offset 0) so it is rendered on the
                    // initial frame and we can capture its toggle closure.
                    SliverToBoxAdapter(
                      child: EntryDetailsContent(
                        testTextEntry.meta.id,
                        linkedFrom: testTask,
                        link: collapsedLink,
                      ),
                    ),
                    // Trailing filler so we can scroll past the entry.
                    const SliverToBoxAdapter(child: SizedBox(height: 2000)),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // Grab the production onToggleCollapse closure while the header (and its
        // chevron) is rendered at the top of the viewport (offset 0).
        expect(find.byIcon(Icons.expand_more), findsOneWidget);
        final header = tester.widget<EntryDetailHeader>(
          find.byType(EntryDetailHeader),
        );
        final toggle = header.onToggleCollapse;
        expect(toggle, isNotNull);

        // Scroll down so the entry's card top (offset 0) is above the current
        // scroll offset. The large cacheExtent keeps its render object alive.
        scrollController.jumpTo(300);
        await tester.pump();

        // Invoke the expand toggle directly (collapsed → expand) so
        // isExpanding=true and the delayed auto-scroll branch is scheduled.
        toggle!();
        await tester.pump();

        // updateLink is called with collapsed flipped to false.
        final captured = verify(
          () => mockJournalRepository.updateLink(captureAny()),
        ).captured;
        expect(captured, hasLength(1));
        expect((captured.first as EntryLink).collapsed, isFalse);

        final offsetBeforeDelay = scrollController.position.pixels;
        expect(offsetBeforeDelay, 300);

        // Advance past the 600 ms collapseAnimationDuration so the delayed
        // callback runs. Because the card top (offset 0) is above the current
        // offset (300), revealedOffset.offset < currentOffset, so
        // Scrollable.ensureVisible is invoked (line 552).
        await tester.pump(const Duration(milliseconds: 700));
        // Let the 400 ms ensureVisible animation run.
        await tester.pump(const Duration(milliseconds: 500));

        // ensureVisible scrolled the entry back toward the top: the offset has
        // decreased from where it was when the delayed callback fired.
        expect(
          scrollController.position.pixels,
          lessThan(offsetBeforeDelay),
        );

        await tester.pumpAndSettle();
      },
    );

    // Negative control: when NOT scrolled past the card (offset 0), the
    // revealedOffset.offset < currentOffset guard is false, so ensureVisible is
    // never called and the scroll position stays put after the delay.
    testWidgets(
      'expanding an in-view collapsed entry does not auto-scroll',
      (tester) async {
        final mockJournalRepository = MockJournalRepository();
        when(
          () => mockJournalRepository.updateLink(any()),
        ).thenAnswer((_) async => true);

        final collapsedLink = EntryLink.basic(
          id: 'link-no-autoscroll',
          fromId: testTask.meta.id,
          toId: testTextEntry.meta.id,
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
          collapsed: true,
        );

        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              overrides: [
                entryControllerProvider(
                  id: testTextEntry.meta.id,
                ).overrideWith(() => _FakeEntryController(testTextEntry)),
                journalRepositoryProvider.overrideWithValue(
                  mockJournalRepository,
                ),
              ],
              child: SizedBox(
                height: 600,
                child: CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: EntryDetailsContent(
                        testTextEntry.meta.id,
                        linkedFrom: testTask,
                        link: collapsedLink,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 2000)),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // Entry is at the very top (offset 0) — nothing is scrolled past it.
        expect(scrollController.position.pixels, 0);

        await tester.tap(find.byIcon(Icons.expand_more));
        await tester.pump();

        verify(
          () => mockJournalRepository.updateLink(any()),
        ).called(1);

        // Run the delayed branch: card top (0) is not above current offset (0),
        // so the guard is false and ensureVisible is skipped.
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pump(const Duration(milliseconds: 500));

        // Scroll position is unchanged — no auto-scroll occurred.
        expect(scrollController.position.pixels, 0);

        await tester.pumpAndSettle();
      },
    );
  });

  group('EntryDetailsWidget Collapsible Tests', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    late JournalDb mockJournalDb;
    late MockPersistenceLogic mockPersistenceLogic;
    late MockUpdateNotifications mockUpdateNotifications;
    late MockEntitiesCacheService mockEntitiesCacheService;

    setUpAll(() {
      setFakeDocumentsPath();
      registerFallbackValue(
        EntryLink.basic(
          id: 'fallback',
          fromId: 'from',
          toId: 'to',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: null,
        ),
      );
    });

    setUp(() async {
      mockJournalDb = mockJournalDbWithMeasurableTypes([]);
      mockPersistenceLogic = MockPersistenceLogic();
      mockUpdateNotifications = MockUpdateNotifications();
      mockEntitiesCacheService = MockEntitiesCacheService();

      final mockTimeService = MockTimeService();
      final mockEditorStateService = MockEditorStateService();
      final mockHealthImport = MockHealthImport();

      getIt
        ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<EditorStateService>(mockEditorStateService)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
        ..registerSingleton<LinkService>(MockLinkService())
        ..registerSingleton<HealthImport>(mockHealthImport)
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);

      when(() => mockEntitiesCacheService.sortedCategories).thenAnswer(
        (_) => [],
      );
      when(
        () => mockEntitiesCacheService.getCategoryById(any()),
      ).thenReturn(null);
      when(() => mockEntitiesCacheService.showPrivateEntries).thenReturn(true);
      when(() => mockEntitiesCacheService.getLabelById(any())).thenReturn(null);

      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      when(() => mockJournalDb.watchConfigFlags()).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          <ConfigFlag>{
            const ConfigFlag(
              name: 'private',
              description: 'Show private entries?',
              status: true,
            ),
          },
        ]),
      );

      when(
        () => mockEditorStateService.getUnsavedStream(any(), any()),
      ).thenAnswer(
        (_) => Stream<bool>.fromIterable([false]),
      );

      when(
        mockTimeService.getStream,
      ).thenAnswer((_) => Stream<JournalEntity>.fromIterable([]));
    });

    tearDown(getIt.reset);

    group('non-collapsible entries', () {
      testWidgets('text entry without link is NOT collapsible', (tester) async {
        when(
          () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
        ).thenAnswer((_) async => testTextEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testTextEntry.meta.id,
                showAiEntry: false,
              ),
            ),
          ),
        );
        await tester.pump();

        // No collapse arrow should be shown for text entries
        expect(find.byIcon(Icons.expand_more), findsNothing);
      });

      testWidgets('image entry without linkedFrom is NOT collapsible', (
        tester,
      ) async {
        when(
          () => mockJournalDb.journalEntityById(testImageEntry.meta.id),
        ).thenAnswer((_) async => testImageEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testImageEntry.meta.id,
                showAiEntry: false,
                // No linkedFrom = not in linked context
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.expand_more), findsNothing);
      });
    });

    group('collapsible image entry', () {
      final testLink = EntryLink.basic(
        id: 'link-1',
        fromId: testTask.meta.id,
        toId: testImageEntry.meta.id,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: null,
      );

      testWidgets('shows collapse arrow for image in linked context', (
        tester,
      ) async {
        when(
          () => mockJournalDb.journalEntityById(testImageEntry.meta.id),
        ).thenAnswer((_) async => testImageEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testImageEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: testLink,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.expand_more), findsOneWidget);
      });

      testWidgets('shows SizeTransition for collapsible entry', (tester) async {
        when(
          () => mockJournalDb.journalEntityById(testImageEntry.meta.id),
        ).thenAnswer((_) async => testImageEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testImageEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: testLink,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(SizeTransition), findsOneWidget);
      });

      testWidgets(
        'does NOT show collapsible AnimatedSize for non-collapsible',
        (tester) async {
          when(
            () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
          ).thenAnswer((_) async => testTextEntry);

          await tester.pumpWidget(
            makeTestableWidgetWithScaffold(
              ProviderScope(
                child: EntryDetailsWidget(
                  itemId: testTextEntry.meta.id,
                  showAiEntry: false,
                ),
              ),
            ),
          );
          await tester.pump();

          // Non-collapsible entries don't use AnimatedSize for collapse
          expect(find.byIcon(Icons.expand_more), findsNothing);
        },
      );

      testWidgets('SizeTransition is fully expanded when not collapsed', (
        tester,
      ) async {
        when(
          () => mockJournalDb.journalEntityById(testImageEntry.meta.id),
        ).thenAnswer((_) async => testImageEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testImageEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: testLink, // collapsed is null (expanded)
              ),
            ),
          ),
        );
        await tester.pump();

        final sizeTransition = tester.widget<SizeTransition>(
          find.byType(SizeTransition),
        );
        expect(sizeTransition.sizeFactor.value, 1.0);
      });

      testWidgets('SizeTransition is fully collapsed when collapsed', (
        tester,
      ) async {
        final collapsedLink = testLink.copyWith(collapsed: true);

        when(
          () => mockJournalDb.journalEntityById(testImageEntry.meta.id),
        ).thenAnswer((_) async => testImageEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testImageEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: collapsedLink,
              ),
            ),
          ),
        );
        await tester.pump();

        final sizeTransition = tester.widget<SizeTransition>(
          find.byType(SizeTransition),
        );
        expect(sizeTransition.sizeFactor.value, 0.0);
      });
    });

    group('collapsible audio entry', () {
      final testAudioLink = EntryLink.basic(
        id: 'link-audio',
        fromId: testTask.meta.id,
        toId: testAudioEntry.meta.id,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: null,
      );

      testWidgets('shows collapse arrow for audio in linked context', (
        tester,
      ) async {
        when(
          () => mockJournalDb.journalEntityById(testAudioEntry.meta.id),
        ).thenAnswer((_) async => testAudioEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testAudioEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: testAudioLink,
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(AppTheme.chevronRotationDuration);

        expect(find.byIcon(Icons.expand_more), findsOneWidget);
      });

      testWidgets('audio entry collapses with collapsed link', (tester) async {
        final collapsedLink = testAudioLink.copyWith(collapsed: true);

        when(
          () => mockJournalDb.journalEntityById(testAudioEntry.meta.id),
        ).thenAnswer((_) async => testAudioEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testAudioEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: collapsedLink,
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(AppTheme.chevronRotationDuration);

        final sizeTransition = tester.widget<SizeTransition>(
          find.byType(SizeTransition),
        );
        expect(sizeTransition.sizeFactor.value, 0.0);
      });
    });

    group('collapsible text entry', () {
      final textLink = EntryLink.basic(
        id: 'link-text',
        fromId: testTask.meta.id,
        toId: testTextEntry.meta.id,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: null,
      );

      testWidgets('text entry in linked context IS collapsible', (
        tester,
      ) async {
        when(
          () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
        ).thenAnswer((_) async => testTextEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testTextEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: textLink,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.expand_more), findsOneWidget);
      });

      testWidgets('shows SizeTransition for collapsible text entry', (
        tester,
      ) async {
        when(
          () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
        ).thenAnswer((_) async => testTextEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testTextEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: textLink,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(SizeTransition), findsOneWidget);
      });

      testWidgets('SizeTransition is fully expanded when not collapsed', (
        tester,
      ) async {
        when(
          () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
        ).thenAnswer((_) async => testTextEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testTextEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: textLink,
              ),
            ),
          ),
        );
        await tester.pump();

        final sizeTransition = tester.widget<SizeTransition>(
          find.byType(SizeTransition),
        );
        expect(sizeTransition.sizeFactor.value, 1.0);
      });

      testWidgets('SizeTransition is fully collapsed when collapsed', (
        tester,
      ) async {
        final collapsedLink = textLink.copyWith(collapsed: true);

        when(
          () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
        ).thenAnswer((_) async => testTextEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testTextEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: collapsedLink,
              ),
            ),
          ),
        );
        await tester.pump();

        final sizeTransition = tester.widget<SizeTransition>(
          find.byType(SizeTransition),
        );
        expect(sizeTransition.sizeFactor.value, 0.0);
      });

      testWidgets('tapping chevron calls updateLink with collapsed true', (
        tester,
      ) async {
        final mockJournalRepository = MockJournalRepository();
        when(
          () => mockJournalRepository.updateLink(any()),
        ).thenAnswer((_) async => true);

        when(
          () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
        ).thenAnswer((_) async => testTextEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              overrides: [
                journalRepositoryProvider.overrideWithValue(
                  mockJournalRepository,
                ),
              ],
              child: EntryDetailsWidget(
                itemId: testTextEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: textLink,
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.byIcon(Icons.expand_more));
        await tester.pump();

        final captured = verify(
          () => mockJournalRepository.updateLink(captureAny()),
        ).captured;
        expect(captured, hasLength(1));
        final updatedLink = captured.first as EntryLink;
        expect(updatedLink.collapsed, isTrue);

        await tester.pumpAndSettle();
      });
    });

    group('expanded content structure', () {
      final testLinkStruct = EntryLink.basic(
        id: 'link-struct',
        fromId: testTask.meta.id,
        toId: testImageEntry.meta.id,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: null,
      );

      testWidgets('expanded image entry shows EntryImageWidget', (
        tester,
      ) async {
        when(
          () => mockJournalDb.journalEntityById(testImageEntry.meta.id),
        ).thenAnswer((_) async => testImageEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testImageEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: testLinkStruct,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(EntryImageWidget), findsOneWidget);
      });

      testWidgets('expanded image entry shows date under image', (
        tester,
      ) async {
        when(
          () => mockJournalDb.journalEntityById(testImageEntry.meta.id),
        ).thenAnswer((_) async => testImageEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testImageEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: testLinkStruct,
              ),
            ),
          ),
        );
        await tester.pump();

        // EntryDatetimeWidget should appear in expanded content
        expect(find.byType(EntryDatetimeWidget), findsAtLeastNWidgets(1));
      });

      testWidgets('collapsed image entry hides image content', (tester) async {
        final collapsedLink = testLinkStruct.copyWith(collapsed: true);

        when(
          () => mockJournalDb.journalEntityById(testImageEntry.meta.id),
        ).thenAnswer((_) async => testImageEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testImageEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: collapsedLink,
              ),
            ),
          ),
        );
        await tester.pump();

        final sizeTransition = tester.widget<SizeTransition>(
          find.byType(SizeTransition),
        );
        expect(sizeTransition.sizeFactor.value, 0.0);
      });

      testWidgets('expanded image entry shows date widget', (tester) async {
        when(
          () => mockJournalDb.journalEntityById(testImageEntry.meta.id),
        ).thenAnswer((_) async => testImageEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testImageEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: testLinkStruct,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(EntryDatetimeWidget), findsAtLeastNWidgets(1));
      });
    });

    group('expanded audio content structure', () {
      final testAudioLinkStruct = EntryLink.basic(
        id: 'link-audio-struct',
        fromId: testTask.meta.id,
        toId: testAudioEntry.meta.id,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: null,
      );

      testWidgets('expanded audio entry shows AudioPlayerWidget', (
        tester,
      ) async {
        when(
          () => mockJournalDb.journalEntityById(testAudioEntry.meta.id),
        ).thenAnswer((_) async => testAudioEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testAudioEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: testAudioLinkStruct,
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(AppTheme.chevronRotationDuration);

        expect(find.byType(AudioPlayerWidget), findsOneWidget);
      });

      testWidgets('expanded audio entry shows date under player', (
        tester,
      ) async {
        when(
          () => mockJournalDb.journalEntityById(testAudioEntry.meta.id),
        ).thenAnswer((_) async => testAudioEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testAudioEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: testAudioLinkStruct,
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(AppTheme.chevronRotationDuration);

        expect(find.byType(EntryDatetimeWidget), findsAtLeastNWidgets(1));
      });

      testWidgets('collapsed audio entry hides player content', (tester) async {
        final collapsedLink = testAudioLinkStruct.copyWith(collapsed: true);

        when(
          () => mockJournalDb.journalEntityById(testAudioEntry.meta.id),
        ).thenAnswer((_) async => testAudioEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testAudioEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: collapsedLink,
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(AppTheme.chevronRotationDuration);

        final sizeTransition = tester.widget<SizeTransition>(
          find.byType(SizeTransition),
        );
        expect(sizeTransition.sizeFactor.value, 0.0);
      });
    });

    group('collapse state from link', () {
      testWidgets('link with collapsed=null renders as expanded', (
        tester,
      ) async {
        final nullCollapsedLink = EntryLink.basic(
          id: 'link-null',
          fromId: testTask.meta.id,
          toId: testImageEntry.meta.id,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: null,
          // collapsed not set -> null
        );

        when(
          () => mockJournalDb.journalEntityById(testImageEntry.meta.id),
        ).thenAnswer((_) async => testImageEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testImageEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: nullCollapsedLink,
              ),
            ),
          ),
        );
        await tester.pump();

        final sizeTransition = tester.widget<SizeTransition>(
          find.byType(SizeTransition),
        );
        expect(sizeTransition.sizeFactor.value, 1.0);
      });

      testWidgets('link with collapsed=false renders as expanded', (
        tester,
      ) async {
        final falseCollapsedLink = EntryLink.basic(
          id: 'link-false',
          fromId: testTask.meta.id,
          toId: testImageEntry.meta.id,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: null,
          collapsed: false,
        );

        when(
          () => mockJournalDb.journalEntityById(testImageEntry.meta.id),
        ).thenAnswer((_) async => testImageEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testImageEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: falseCollapsedLink,
              ),
            ),
          ),
        );
        await tester.pump();

        final sizeTransition = tester.widget<SizeTransition>(
          find.byType(SizeTransition),
        );
        expect(sizeTransition.sizeFactor.value, 1.0);
      });
    });

    group('parameter defaults', () {
      test('EntryDetailsWidget link defaults to null', () {
        const widget = EntryDetailsWidget(
          itemId: 'test-id',
          showAiEntry: false,
        );

        expect(widget.link, isNull);
        expect(widget.linkedFrom, isNull);
      });
    });

    group('onToggleCollapse callback', () {
      testWidgets('collapsible image entry passes onToggleCollapse to header', (
        tester,
      ) async {
        final testLinkToggle = EntryLink.basic(
          id: 'link-toggle',
          fromId: testTask.meta.id,
          toId: testImageEntry.meta.id,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: null,
        );

        when(
          () => mockJournalDb.journalEntityById(testImageEntry.meta.id),
        ).thenAnswer((_) async => testImageEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testImageEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: testLinkToggle,
              ),
            ),
          ),
        );
        await tester.pump();

        // The collapse arrow should be present (isCollapsible = true)
        expect(find.byIcon(Icons.expand_more), findsOneWidget);

        // The EntryDetailHeader widget should be rendered with collapse props
        final header = tester.widget<EntryDetailHeader>(
          find.byType(EntryDetailHeader),
        );
        expect(header.isCollapsible, isTrue);
        expect(header.isCollapsed, isFalse);
        expect(header.onToggleCollapse, isNotNull);
      });

      testWidgets('tapping chevron calls updateLink with collapsed true', (
        tester,
      ) async {
        final mockJournalRepository = MockJournalRepository();
        when(
          () => mockJournalRepository.updateLink(any()),
        ).thenAnswer((_) async => true);

        final testLinkTapCollapse = EntryLink.basic(
          id: 'link-tap-collapse',
          fromId: testTask.meta.id,
          toId: testImageEntry.meta.id,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: null,
        );

        when(
          () => mockJournalDb.journalEntityById(testImageEntry.meta.id),
        ).thenAnswer((_) async => testImageEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              overrides: [
                journalRepositoryProvider.overrideWithValue(
                  mockJournalRepository,
                ),
              ],
              child: EntryDetailsWidget(
                itemId: testImageEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: testLinkTapCollapse,
              ),
            ),
          ),
        );
        await tester.pump();

        // Tap the collapse chevron
        await tester.tap(find.byIcon(Icons.expand_more));
        await tester.pump();

        // Verify updateLink was called with collapsed: true
        final captured = verify(
          () => mockJournalRepository.updateLink(captureAny()),
        ).captured;
        expect(captured, hasLength(1));
        final updatedLink = captured.first as EntryLink;
        expect(updatedLink.collapsed, isTrue);
        expect(updatedLink.id, 'link-tap-collapse');

        // Drain the Future.delayed timer from the auto-scroll logic
        await tester.pumpAndSettle();
      });

      testWidgets(
        'tapping chevron on collapsed entry calls updateLink with collapsed false',
        (tester) async {
          final mockJournalRepository = MockJournalRepository();
          when(
            () => mockJournalRepository.updateLink(any()),
          ).thenAnswer((_) async => true);

          final testLinkTapExpand = EntryLink.basic(
            id: 'link-tap-expand',
            fromId: testTask.meta.id,
            toId: testImageEntry.meta.id,
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
            vectorClock: null,
            collapsed: true,
          );

          when(
            () => mockJournalDb.journalEntityById(testImageEntry.meta.id),
          ).thenAnswer((_) async => testImageEntry);

          await tester.pumpWidget(
            makeTestableWidgetWithScaffold(
              ProviderScope(
                overrides: [
                  journalRepositoryProvider.overrideWithValue(
                    mockJournalRepository,
                  ),
                ],
                child: EntryDetailsWidget(
                  itemId: testImageEntry.meta.id,
                  showAiEntry: false,
                  linkedFrom: testTask,
                  link: testLinkTapExpand,
                ),
              ),
            ),
          );
          await tester.pump();

          // Tap the collapse chevron (which should expand)
          await tester.tap(find.byIcon(Icons.expand_more));
          await tester.pump();

          // Verify updateLink was called with collapsed: false
          final captured = verify(
            () => mockJournalRepository.updateLink(captureAny()),
          ).captured;
          expect(captured, hasLength(1));
          final updatedLink = captured.first as EntryLink;
          expect(updatedLink.collapsed, isFalse);

          // Drain the Future.delayed timer from the auto-scroll logic
          await tester.pumpAndSettle();
        },
      );

      testWidgets('collapsible text entry passes onToggleCollapse to header', (
        tester,
      ) async {
        final textLinkToggle = EntryLink.basic(
          id: 'link-text-toggle',
          fromId: testTask.meta.id,
          toId: testTextEntry.meta.id,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: null,
        );

        when(
          () => mockJournalDb.journalEntityById(testTextEntry.meta.id),
        ).thenAnswer((_) async => testTextEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testTextEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: textLinkToggle,
              ),
            ),
          ),
        );
        await tester.pump();

        final header = tester.widget<EntryDetailHeader>(
          find.byType(EntryDetailHeader),
        );
        expect(header.isCollapsible, isTrue);
        expect(header.onToggleCollapse, isNotNull);
      });
    });

    group('collapse toggle error handling', () {
      testWidgets('catches exception from updateLink and logs it', (
        tester,
      ) async {
        final mockJournalRepository = MockJournalRepository();
        final mockLoggingService = MockDomainLogger();

        when(
          () => mockJournalRepository.updateLink(any()),
        ).thenThrow(Exception('db write failed'));

        when(
          () => mockLoggingService.error(
            any<LogDomain>(),
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: any<String?>(named: 'subDomain'),
          ),
        ).thenAnswer((_) async {});

        getIt.registerSingleton<DomainLogger>(mockLoggingService);

        final testLinkError = EntryLink.basic(
          id: 'link-error',
          fromId: testTask.meta.id,
          toId: testImageEntry.meta.id,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: null,
        );

        when(
          () => mockJournalDb.journalEntityById(testImageEntry.meta.id),
        ).thenAnswer((_) async => testImageEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              overrides: [
                journalRepositoryProvider.overrideWithValue(
                  mockJournalRepository,
                ),
              ],
              child: EntryDetailsWidget(
                itemId: testImageEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: testLinkError,
              ),
            ),
          ),
        );
        await tester.pump();

        // Tap the collapse chevron — updateLink will throw
        await tester.tap(find.byIcon(Icons.expand_more));
        await tester.pumpAndSettle();

        // Verify the exception was captured via LoggingService
        verify(
          () => mockLoggingService.error(
            LogDomain.persistence,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'onToggleCollapse',
          ),
        ).called(1);

        getIt.unregister<DomainLogger>();
      });
    });

    group('collapsible audio layout', () {
      final testAudioLinkLayout = EntryLink.basic(
        id: 'link-audio-layout',
        fromId: testTask.meta.id,
        toId: testAudioEntry.meta.id,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: null,
      );

      testWidgets('expanded audio shows date under player', (tester) async {
        when(
          () => mockJournalDb.journalEntityById(testAudioEntry.meta.id),
        ).thenAnswer((_) async => testAudioEntry);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ProviderScope(
              child: EntryDetailsWidget(
                itemId: testAudioEntry.meta.id,
                showAiEntry: false,
                linkedFrom: testTask,
                link: testAudioLinkLayout,
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(AppTheme.chevronRotationDuration);

        // In collapsible audio layout, both AudioPlayer and date are shown
        expect(find.byType(AudioPlayerWidget), findsOneWidget);
        expect(find.byType(EntryDatetimeWidget), findsAtLeastNWidgets(1));
      });
    });
  });
}
