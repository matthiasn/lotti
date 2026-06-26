import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/categories/ui/widgets/category_selection_icon_button.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fake_entry_controller.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockEntitiesCacheService mockCache;

  final pickable = CategoryDefinition(
    id: 'cat-pick',
    name: 'Focus',
    color: '#FF0000',
    createdAt: DateTime(2024, 3, 15, 10, 30),
    updatedAt: DateTime(2024, 3, 15, 10, 30),
    vectorClock: null,
    private: false,
    active: true,
  );

  setUp(() async {
    await getIt.reset();
    getIt.allowReassignment = true;

    mockCache = MockEntitiesCacheService();
    when(() => mockCache.getCategoryById(any())).thenReturn(null);
    when(() => mockCache.sortedCategories).thenReturn([pickable]);

    final mockUpdateNotifications = MockUpdateNotifications();
    when(
      () => mockUpdateNotifications.updateStream,
    ).thenAnswer((_) => const Stream<Set<String>>.empty());

    getIt
      ..registerSingleton<EntitiesCacheService>(mockCache)
      ..registerSingleton<EditorStateService>(MockEditorStateService())
      ..registerSingleton<JournalDb>(MockJournalDb())
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<PersistenceLogic>(MockPersistenceLogic());
  });

  tearDown(() async {
    await getIt.reset();
  });

  Widget pumpInNestedNavigator({required ToggleCallTracker tracker}) {
    return ProviderScope(
      overrides: [
        entryControllerProvider(testTextEntry.id).overrideWith(
          () => FakeEntryController(testTextEntry, tracker: tracker),
        ),
      ],
      child: MaterialApp(
        theme: resolveTestTheme(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          FormBuilderLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                body: CategorySelectionIconButton(entry: testTextEntry),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders the category icon button', (tester) async {
    final tracker = ToggleCallTracker();
    await tester.pumpWidget(pumpInNestedNavigator(tracker: tracker));
    await tester.pumpAndSettle();

    expect(find.byType(IconButton), findsOneWidget);
    expect(find.byType(CategoryIconCompact), findsOneWidget);
  });

  testWidgets(
    'tapping a category row updates the entry and closes the modal '
    'without popping the outer nested route',
    (tester) async {
      // The journal page lives in a per-tab nested Navigator while the
      // picker is pushed onto the root Navigator on phone widths
      // (`shouldUseRootNavigatorForBottomSheet`). A pop targeting the
      // outer page context would dismiss the wrong stack.
      final tracker = ToggleCallTracker();
      await tester.pumpWidget(pumpInNestedNavigator(tracker: tracker));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(find.byType(CategoryPickerSheet), findsOneWidget);

      await tester.tap(find.text('Focus'));
      await tester.pumpAndSettle();

      expect(tracker.updateCategoryIdCalls, equals(['cat-pick']));
      // Modal closed.
      expect(find.byType(CategoryPickerSheet), findsNothing);
      // Outer nested route was NOT popped — the icon button is still
      // mounted. A pop targeting the outer context would have removed
      // the MaterialPageRoute hosting it.
      expect(find.byType(CategorySelectionIconButton), findsOneWidget);
    },
  );
}
