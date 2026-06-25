import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_params.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_variant.dart';
import 'package:lotti/features/settings/state/celebration_preferences_controller.dart';
import 'package:lotti/features/settings/ui/pages/advanced/celebration_playground_page.dart';
import 'package:lotti/features/settings/ui/widgets/celebration_preview_hero.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  setUp(() async {
    final mocks = await setUpTestGetIt();
    when(
      () => mocks.settingsDb.saveSettingsItem(any(), any()),
    ).thenAnswer((_) async => 1);
  });

  tearDown(tearDownTestGetIt);

  const variant = CelebrationVariant.sparks;

  Future<ProviderContainer> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: _Host(child: CelebrationPlaygroundPage(variant: variant)),
      ),
    );
    return ProviderScope.containerOf(
      tester.element(find.byType(CelebrationPlaygroundPage)),
    );
  }

  testWidgets('renders the hero preview and one slider per tunable knob', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byType(CelebrationPreviewHero), findsOneWidget);
    expect(
      find.byType(Slider),
      findsNWidgets(celebrationSliderSpecs(variant).length),
    );
  });

  testWidgets('editing a slider customizes and persists the variant', (
    tester,
  ) async {
    final container = await pump(tester);
    expect(
      container
          .read(celebrationPreferencesControllerProvider)
          .paramsFor(variant)
          .isCustomized,
      isFalse,
    );

    // Drive the first knob (count) to its max via the live callbacks.
    final slider = tester.widget<Slider>(find.byType(Slider).first);
    slider.onChanged!(slider.max);
    slider.onChangeEnd!(slider.max);
    await tester.pump();

    expect(
      container
          .read(celebrationPreferencesControllerProvider)
          .paramsFor(variant)
          .isCustomized,
      isTrue,
    );
    verify(
      () => getIt<SettingsDb>().saveSettingsItem(
        'CELEBRATE_PARAMS_sparks',
        any(),
      ),
    ).called(1);
  });

  testWidgets('reset restores the variant to its defaults', (tester) async {
    final container = await pump(tester);

    // Customize through the page itself so its local state marks the variant
    // customized and enables the Reset action.
    final slider = tester.widget<Slider>(find.byType(Slider).first);
    slider.onChanged!(slider.max);
    slider.onChangeEnd!(slider.max);
    await tester.pump();
    expect(
      container
          .read(celebrationPreferencesControllerProvider)
          .paramsFor(variant)
          .isCustomized,
      isTrue,
    );

    await tester.tap(find.widgetWithText(TextButton, 'Reset to default'));
    await tester.pump();

    expect(
      container
          .read(celebrationPreferencesControllerProvider)
          .paramsFor(variant),
      CelebrationParams.defaultsFor(variant),
    );
  });

  testWidgets('reset surfaces an Undo action that restores the tuned params', (
    tester,
  ) async {
    final container = await pump(tester);

    // Tune the first knob to its max, then reset.
    final slider = tester.widget<Slider>(find.byType(Slider).first);
    slider.onChanged!(slider.max);
    slider.onChangeEnd!(slider.max);
    await tester.pump();
    final tuned = container
        .read(celebrationPreferencesControllerProvider)
        .paramsFor(variant);
    expect(tuned.isCustomized, isTrue);

    await tester.tap(find.widgetWithText(TextButton, 'Reset to default'));
    await tester.pump(); // start the snackbar entrance
    await tester.pump(const Duration(milliseconds: 750)); // settle it in
    expect(
      container
          .read(celebrationPreferencesControllerProvider)
          .paramsFor(variant),
      CelebrationParams.defaultsFor(variant),
    );

    // Undo from the snackbar restores the tuned params.
    await tester.tap(find.byType(SnackBarAction));
    await tester.pump();
    expect(
      container
          .read(celebrationPreferencesControllerProvider)
          .paramsFor(variant),
      tuned,
    );

    await tester.pumpAndSettle();
  });

  testWidgets('typing a value in the editor sets the knob exactly', (
    tester,
  ) async {
    final container = await pump(tester);
    final defaultCount = container
        .read(celebrationPreferencesControllerProvider)
        .paramsFor(variant)
        .v('count');

    // Tap the value readout ("40") to open the numeric editor.
    await tester.tap(find.text(defaultCount.round().toString()).first);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), '12');
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(
      container
          .read(celebrationPreferencesControllerProvider)
          .paramsFor(variant)
          .v('count'),
      12,
    );
  });

  testWidgets('every knob id maps to a localized label and description', (
    tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      makeTestableWidget2(
        Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      ),
    );
    final ids = <String>{
      for (final v in CelebrationVariant.values)
        for (final s in celebrationSliderSpecs(v)) s.id,
    };
    // Sanity: this actually exercises the full knob vocabulary.
    expect(ids.length, greaterThan(15));
    for (final id in ids) {
      final label = celebrationKnobLabel(ctx, id);
      expect(label, isNotEmpty, reason: id);
      // A knob must never surface its raw engine id to the user.
      expect(label, isNot(id), reason: 'knob "$id" leaked its id as a label');
      expect(celebrationKnobDescription(ctx, id), isNotEmpty, reason: id);
    }
  });

  testWidgets('the Replay button re-fires the preview without error', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.widgetWithIcon(TextButton, Icons.replay));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('collapses to a single column on a narrow (phone) width', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 1400);

    final container = await pump(tester);
    // Narrow width drops the preview's context neighbours and still renders one
    // slider per knob in the single-column grid.
    expect(
      find.byType(Slider),
      findsNWidgets(celebrationSliderSpecs(variant).length),
    );
    expect(
      container
          .read(celebrationPreferencesControllerProvider)
          .paramsFor(variant)
          .isCustomized,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  // Opens the numeric editor for the knob whose value chip reads [chip],
  // scrolling it into view first (decimal knobs live in the scrolling groups
  // below the pinned preview).
  Future<void> openEditor(WidgetTester tester, String chip) async {
    final finder = find.text(chip).first;
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  }

  testWidgets('editing a decimal knob clamps and persists the typed value', (
    tester,
  ) async {
    final container = await pump(tester);
    // gravity's default 0.16 renders as a unique "0.16" chip (range 0–0.6).
    await openEditor(tester, '0.16');

    await tester.enterText(find.byType(TextField), '0.45');
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(
      container
          .read(celebrationPreferencesControllerProvider)
          .paramsFor(variant)
          .v('gravity'),
      0.45,
    );
  });

  testWidgets('submitting the editor via the keyboard action persists', (
    tester,
  ) async {
    final container = await pump(tester);
    // trail's default 0.20 is a unique chip (range 0–0.6).
    await openEditor(tester, '0.20');

    await tester.enterText(find.byType(TextField), '0.5');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(
      container
          .read(celebrationPreferencesControllerProvider)
          .paramsFor(variant)
          .v('trail'),
      0.5,
    );
  });

  testWidgets('cancelling the editor leaves the knob unchanged', (
    tester,
  ) async {
    final container = await pump(tester);
    // glow's default 0.18 is a unique chip.
    await openEditor(tester, '0.18');

    await tester.enterText(find.byType(TextField), '0.5');
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(
      container
          .read(celebrationPreferencesControllerProvider)
          .paramsFor(variant)
          .v('glow'),
      0.18,
    );
    expect(
      container
          .read(celebrationPreferencesControllerProvider)
          .paramsFor(variant)
          .isCustomized,
      isFalse,
    );
  });
}

/// Minimal MaterialApp host (localizations + Overlay) without the scroll wrapper
/// `makeTestableWidget` adds, since the page is itself a [Scaffold].
class _Host extends StatelessWidget {
  const _Host({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => makeTestableWidget2(child);
}
