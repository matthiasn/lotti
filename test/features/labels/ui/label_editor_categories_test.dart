import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/ui/widgets/label_editor_sheet.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

class _MockLabelsRepository extends Mock implements LabelsRepository {}

void main() {
  late MockEntitiesCacheService cacheService;
  late _MockLabelsRepository repository;

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
    repository = _MockLabelsRepository();

    await getIt.reset();
    getIt.registerSingleton<EntitiesCacheService>(cacheService);

    when(() => cacheService.sortedCategories)
        .thenReturn([categoryWork, categoryHome]);
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
        // ignore: prefer_const_constructors
        child: MaterialApp(
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

  testWidgets('shows heading and empty state for categories', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Applicable categories'), findsOneWidget);
    expect(find.text('Applies to all categories'), findsOneWidget);
  });

  testWidgets('adds and removes category via modal and chip', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 2000);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // Add category via modal
    expect(find.text('Add category'), findsOneWidget);
    await tester.ensureVisible(find.text('Add category'));
    await tester.ensureVisible(find.text('Add category'));
    await tester.tap(find.text('Add category'));
    await tester.pumpAndSettle();

    // Select "Work" from the modal list and confirm
    await tester.tap(find.text('Work').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();

    // Chip rendered with Work
    expect(find.widgetWithText(InputChip, 'Work'), findsOneWidget);
    expect(find.text('Applies to all categories'), findsNothing);

    // Remove the chip via its delete action
    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();

    expect(find.text('Applies to all categories'), findsOneWidget);
  });

  testWidgets('saving forwards applicableCategoryIds to repository',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 2000);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
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

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // Add category via modal and save
    await tester.ensureVisible(find.text('Add category'));
    await tester.ensureVisible(find.text('Add category'));
    await tester.tap(find.text('Add category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InputChip, 'Work'), findsOneWidget);

    final createButton = find.widgetWithText(FilledButton, 'Create');
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pumpAndSettle();

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
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 2000);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // Add both categories in one modal (multi-select)
    await tester.ensureVisible(find.text('Add category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();

    // Save
    final createButton = find.widgetWithText(FilledButton, 'Create');
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pumpAndSettle();

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

  testWidgets('chips use category color and contrast-aware text',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 2000);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
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

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // Add both categories via the modal (multi-select now)
    await tester.ensureVisible(find.text('Add category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bright').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deep').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();

    final brightChip =
        tester.widget<InputChip>(find.widgetWithText(InputChip, 'Bright'));
    final deepChip =
        tester.widget<InputChip>(find.widgetWithText(InputChip, 'Deep'));

    // Background colors reflect category colors
    expect(brightChip.backgroundColor, const Color(0xFFF9F871));
    expect(deepChip.backgroundColor, const Color(0xFF3D0066));

    // Foreground contrast: light bg -> black; dark bg -> white
    expect(brightChip.labelStyle?.color, Colors.black);
    expect(brightChip.deleteIconColor, Colors.black);
    expect(deepChip.labelStyle?.color, Colors.white);
    expect(deepChip.deleteIconColor, Colors.white);
  });
}
