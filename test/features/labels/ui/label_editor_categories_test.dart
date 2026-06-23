import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/ui/widgets/category_selection_chip.dart';
import 'package:lotti/features/labels/ui/widgets/label_editor_sheet.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

void main() {
  late MockEntitiesCacheService cacheService;
  late MockLabelsRepository repository;

  final categoryWork = CategoryDefinition(
    id: 'work',
    name: 'Work',
    color: '#0000FF',
    createdAt: testEpochDateTime,
    updatedAt: testEpochDateTime,
    vectorClock: null,
    active: true,
    private: false,
  );

  final categoryHome = CategoryDefinition(
    id: 'home',
    name: 'Home',
    color: '#00FF00',
    createdAt: testEpochDateTime,
    updatedAt: testEpochDateTime,
    vectorClock: null,
    active: true,
    private: false,
  );

  setUp(() async {
    cacheService = MockEntitiesCacheService();
    repository = MockLabelsRepository();

    await getIt.reset();
    getIt.registerSingleton<EntitiesCacheService>(cacheService);

    when(
      () => cacheService.sortedCategories,
    ).thenReturn([categoryWork, categoryHome]);
    when(() => cacheService.getCategoryById('work')).thenReturn(categoryWork);
    when(() => cacheService.getCategoryById('home')).thenReturn(categoryHome);

    when(repository.getAllLabels).thenAnswer((_) async => <LabelDefinition>[]);
  });

  tearDown(() async {
    await getIt.reset();
  });

  Widget host() {
    return MediaQuery(
      data: const MediaQueryData(size: Size(1200, 1800)),
      child: ProviderScope(
        overrides: [
          labelsRepositoryProvider.overrideWithValue(repository),
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
          home: const Scaffold(
            body: Center(
              child: LabelEditorSheet(initialName: 'Scoped Label'),
            ),
          ),
        ),
      ),
    );
  }

  /// Fixes a large desktop-sized viewport, pumps the editor sheet, and drains
  /// the first frames with bounded pumps. The sheet's data is provided
  /// synchronously via mocks, so no `pumpAndSettle` is needed to render it.
  Future<void> pumpCategoriesEditor(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 2000);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(host());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Opens the "Add category" modal, toggles each [categoryNames] entry on, and
  /// confirms with Done. Modal animations are fixed-duration, so bounded pumps
  /// replace `pumpAndSettle`.
  Future<void> addCategoriesViaModal(
    WidgetTester tester,
    List<String> categoryNames,
  ) async {
    await tester.ensureVisible(find.text('Add category'));
    await tester.tap(find.text('Add category'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    for (final name in categoryNames) {
      await tester.tap(find.text(name).first);
      await tester.pump();
    }

    // The unified category multi-picker commits via its glass Apply footer
    // (keyed), not the old modal's FilledButton "Done".
    await tester.tap(find.byKey(const ValueKey('category-picker-apply')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('shows heading and empty state for categories', (tester) async {
    await pumpCategoriesEditor(tester);

    expect(find.text('Applicable categories'), findsOneWidget);
    expect(find.text('Applies to all categories'), findsOneWidget);
  });

  testWidgets('adds and removes category via modal and chip', (tester) async {
    await pumpCategoriesEditor(tester);

    expect(find.text('Add category'), findsOneWidget);
    await addCategoriesViaModal(tester, ['Work']);

    // Chip rendered with Work
    expect(
      find.widgetWithText(CategorySelectionChip, 'Work'),
      findsOneWidget,
    );
    expect(find.text('Applies to all categories'), findsNothing);

    // Remove the chip via its delete action
    await tester.tap(find.byTooltip('Remove'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Applies to all categories'), findsOneWidget);
  });

  testWidgets('saving forwards applicableCategoryIds to repository', (
    tester,
  ) async {
    final created = testLabelDefinition1.copyWith(
      id: 'label-x',
      name: 'Scoped Label',
      applicableCategoryIds: const ['work'],
    );
    when(
      () => repository.createLabel(
        name: any(named: 'name'),
        color: any(named: 'color'),
        description: any(named: 'description'),
        private: any(named: 'private'),
        sortOrder: any(named: 'sortOrder'),
        applicableCategoryIds: any(named: 'applicableCategoryIds'),
      ),
    ).thenAnswer((_) async => created);

    await pumpCategoriesEditor(tester);

    // Add category via modal and save
    await addCategoriesViaModal(tester, ['Work']);
    expect(
      find.widgetWithText(CategorySelectionChip, 'Work'),
      findsOneWidget,
    );

    final createButton = find.widgetWithText(DesignSystemButton, 'Create');
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    verify(
      () => repository.createLabel(
        name: 'Scoped Label',
        color: any(named: 'color'),
        description: any(named: 'description'),
        private: any(named: 'private'),
        sortOrder: any(named: 'sortOrder'),
        applicableCategoryIds: ['work'],
      ),
    ).called(1);
  });

  testWidgets('saving forwards multiple applicableCategoryIds', (tester) async {
    when(
      () => repository.createLabel(
        name: any(named: 'name'),
        color: any(named: 'color'),
        description: any(named: 'description'),
        private: any(named: 'private'),
        sortOrder: any(named: 'sortOrder'),
        applicableCategoryIds: any(named: 'applicableCategoryIds'),
      ),
    ).thenAnswer((_) async => testLabelDefinition1);

    await pumpCategoriesEditor(tester);

    // Add both categories in one modal (multi-select)
    await addCategoriesViaModal(tester, ['Work', 'Home']);

    // Save
    final createButton = find.widgetWithText(DesignSystemButton, 'Create');
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final captured = verify(
      () => repository.createLabel(
        name: 'Scoped Label',
        color: any(named: 'color'),
        description: any(named: 'description'),
        private: any(named: 'private'),
        sortOrder: any(named: 'sortOrder'),
        applicableCategoryIds: captureAny(named: 'applicableCategoryIds'),
      ),
    ).captured;
    expect(captured, isNotEmpty);
    final ids = List<String>.from(captured.first as List);
    expect(ids.toSet(), {'home', 'work'});
  });

  testWidgets('chips carry each category color as a DsPill tint', (
    tester,
  ) async {
    // Override cache with light and dark categories to validate styling.
    final catLight = CategoryDefinition(
      id: 'cat-light',
      name: 'Bright',
      color: '#F9F871', // light yellow
      createdAt: testEpochDateTime,
      updatedAt: testEpochDateTime,
      vectorClock: null,
      private: false,
      active: true,
    );
    final catDark = CategoryDefinition(
      id: 'cat-dark',
      name: 'Deep',
      color: '#3D0066', // dark purple
      createdAt: testEpochDateTime,
      updatedAt: testEpochDateTime,
      vectorClock: null,
      private: false,
      active: true,
    );

    when(() => cacheService.sortedCategories).thenReturn([catLight, catDark]);
    when(() => cacheService.getCategoryById('cat-light')).thenReturn(catLight);
    when(() => cacheService.getCategoryById('cat-dark')).thenReturn(catDark);

    await pumpCategoriesEditor(tester);

    // Add both categories via the modal (multi-select now)
    await addCategoriesViaModal(tester, ['Bright', 'Deep']);

    final brightChip = tester.widget<CategorySelectionChip>(
      find.widgetWithText(CategorySelectionChip, 'Bright'),
    );
    final deepChip = tester.widget<CategorySelectionChip>(
      find.widgetWithText(CategorySelectionChip, 'Deep'),
    );

    // Each chip is tinted with its own category colour.
    expect(brightChip.color, const Color(0xFFF9F871));
    expect(deepChip.color, const Color(0xFF3D0066));
  });
}
