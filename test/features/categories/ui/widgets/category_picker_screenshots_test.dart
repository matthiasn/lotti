/// Opt-in design-review screenshots of the unified picker, driving the REAL
/// Wolt modals (category single + multi, and the task label picker). Run with:
///
///   LOTTI_CAPTURE_SCREENSHOTS=true fvm flutter test \
///     test/features/categories/ui/widgets/category_picker_screenshots_test.dart
///
/// Writes PNGs under screenshots/category_picker/. Not a golden framework —
/// real widgets at a real device size, dumped for human/agent review.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/labels/ui/widgets/label_selection_modal_utils.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../daily_os_next/screenshot_harness.dart';
import '../../test_utils.dart';

class _MockLabelsRepository extends Mock implements LabelsRepository {}

CategoryDefinition _cat(
  String id,
  String name,
  String color, {
  bool favorite = false,
  bool private = false,
}) => CategoryTestUtils.createTestCategory(
  id: id,
  name: name,
  color: color,
  favorite: favorite,
  private: private,
);

final List<CategoryDefinition> _categories = [
  _cat('cat1', 'Work', '#1F7963', favorite: true),
  _cat('cat2', 'Personal', '#5E8BD4', favorite: true),
  _cat('cat3', 'Health & fitness', '#D45E8B', private: true),
  _cat('cat4', 'Learning', '#D4A85E'),
  _cat('cat5', 'Errands', '#8B5ED4'),
  _cat('cat6', 'Side projects', '#3E9B57'),
];

LabelDefinition _label(String id, String name, String color, [String? desc]) =>
    LabelDefinition(
      id: id,
      name: name,
      color: color,
      description: desc,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      vectorClock: const VectorClock(<String, int>{}),
      private: false,
    );

final List<LabelDefinition> _labels = [
  _label('l1', 'Urgent', '#E5484D', 'Requires immediate attention'),
  _label('l2', 'Blocked', '#F76808'),
  _label('l3', 'Needs review', '#5E8BD4'),
  _label('l4', 'Quick win', '#46A758'),
  _label('l5', 'Waiting on others', '#8B8D98'),
];

void main() {
  if (!screenshotCaptureEnabled) {
    test('category picker screenshots (opt-in)', () {}, skip: true);
    return;
  }

  late MockEntitiesCacheService cache;
  late _MockLabelsRepository labelsRepo;

  setUpAll(loadScreenshotFonts);

  setUp(() {
    cache = MockEntitiesCacheService();
    when(() => cache.sortedCategories).thenReturn(_categories);
    for (final c in _categories) {
      when(() => cache.getCategoryById(c.id)).thenReturn(c);
    }
    for (final l in _labels) {
      when(() => cache.getLabelById(l.id)).thenReturn(l);
    }
    when(() => cache.filterLabelsForCategory(any(), any())).thenReturn(_labels);
    labelsRepo = _MockLabelsRepository();
    if (getIt.isRegistered<EntitiesCacheService>()) {
      getIt.unregister<EntitiesCacheService>();
    }
    getIt.registerSingleton<EntitiesCacheService>(cache);
  });

  tearDown(() => getIt.unregister<EntitiesCacheService>());

  Widget app({
    required Widget home,
    List<Override> overrides = const [],
    bool dark = false,
  }) {
    return RepaintBoundary(
      key: screenshotBoundaryKey,
      child: ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? DesignSystemTheme.dark() : DesignSystemTheme.light(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    );
  }

  Widget opener() => Builder(
    builder: (context) => const Scaffold(
      body: Center(child: Text('open')),
    ),
  );

  testWidgets('category single', (tester) async {
    applyScreenshotDevice(tester, proDevice);
    await tester.pumpWidget(app(home: opener()));
    unawaited(
      showCategoryPicker(
        context: tester.element(find.text('open')),
        title: 'Category',
        currentCategoryId: 'cat3',
        options: _categories,
      ),
    );
    await settleFrames(tester);
    await captureScreenshot(
      tester,
      'category_single',
      subdir: 'category_picker',
    );
  });

  testWidgets('category multi', (tester) async {
    applyScreenshotDevice(tester, proDevice);
    await tester.pumpWidget(app(home: opener()));
    unawaited(
      showCategoryMultiPicker(
        context: tester.element(find.text('open')),
        title: 'Filter by category',
        initialSelectedIds: const {'cat1', 'cat4'},
        options: _categories,
      ),
    );
    await settleFrames(tester);
    await captureScreenshot(
      tester,
      'category_multi',
      subdir: 'category_picker',
    );
  });

  testWidgets('label multi', (tester) async {
    applyScreenshotDevice(tester, proDevice);
    await tester.pumpWidget(
      app(
        overrides: [
          labelsStreamProvider.overrideWith(
            (ref) => Stream<List<LabelDefinition>>.value(_labels),
          ),
          labelsRepositoryProvider.overrideWithValue(labelsRepo),
        ],
        home: opener(),
      ),
    );
    unawaited(
      LabelSelectionModalUtils.openLabelSelector(
        context: tester.element(find.text('open')),
        entryId: 'entry-1',
        initialLabelIds: const ['l1', 'l4'],
      ),
    );
    await settleFrames(tester);
    await captureScreenshot(tester, 'label_multi', subdir: 'category_picker');
  });

  testWidgets('category single (dark)', (tester) async {
    applyScreenshotDevice(tester, proDevice);
    await tester.pumpWidget(app(dark: true, home: opener()));
    unawaited(
      showCategoryPicker(
        context: tester.element(find.text('open')),
        title: 'Category',
        currentCategoryId: 'cat3',
        options: _categories,
      ),
    );
    await settleFrames(tester);
    await captureScreenshot(
      tester,
      'category_single_dark',
      subdir: 'category_picker',
    );
  });

  testWidgets('category multi (dark)', (tester) async {
    applyScreenshotDevice(tester, proDevice);
    await tester.pumpWidget(app(dark: true, home: opener()));
    unawaited(
      showCategoryMultiPicker(
        context: tester.element(find.text('open')),
        title: 'Filter by category',
        initialSelectedIds: const {'cat1', 'cat4'},
        options: _categories,
      ),
    );
    await settleFrames(tester);
    await captureScreenshot(
      tester,
      'category_multi_dark',
      subdir: 'category_picker',
    );
  });

  testWidgets('label multi (dark)', (tester) async {
    applyScreenshotDevice(tester, proDevice);
    await tester.pumpWidget(
      app(
        dark: true,
        overrides: [
          labelsStreamProvider.overrideWith(
            (ref) => Stream<List<LabelDefinition>>.value(_labels),
          ),
          labelsRepositoryProvider.overrideWithValue(labelsRepo),
        ],
        home: opener(),
      ),
    );
    unawaited(
      LabelSelectionModalUtils.openLabelSelector(
        context: tester.element(find.text('open')),
        entryId: 'entry-1',
        initialLabelIds: const ['l1', 'l4'],
      ),
    );
    await settleFrames(tester);
    await captureScreenshot(
      tester,
      'label_multi_dark',
      subdir: 'category_picker',
    );
  });
}
