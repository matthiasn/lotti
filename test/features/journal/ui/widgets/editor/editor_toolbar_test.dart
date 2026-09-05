import 'dart:math' as math;

import 'package:flutter/material.dart' as legacy;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/save_button_controller.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_toolbar.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/themes/legacy_material_bridge.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';

class _TestEntryController extends EntryController {
  @override
  Future<EntryState?> build() async {
    controller = QuillController.basic();
    return EntryState.saved(
      entryId: id,
      entry: null,
      showMap: false,
      isFocused: true,
      shouldShowEditorToolBar: true,
      formKey: formKey,
    );
  }
}

/// Records whether [discard] was invoked so the toolbar's discard control can be
/// asserted to call through to the controller.
class _SpyEntryController extends _TestEntryController {
  bool discardCalled = false;

  @override
  Future<void> discard() async {
    discardCalled = true;
  }
}

/// Forces the save-button state to "unsaved" so the dirty-state controls (the
/// teal save + the discard "X") render regardless of the entry's real state, and
/// records whether [save] was invoked.
class _UnsavedSaveButtonController extends SaveButtonController {
  bool saveCalled = false;

  @override
  Future<bool?> build() async => true;

  @override
  Future<void> save({Duration? estimate}) async {
    saveCalled = true;
  }
}

void main() {
  const entryId = 'toolbar-entry';
  late QuillController quillController;

  setUp(() async {
    final mockUpdateNotifications = MockUpdateNotifications();
    when(() => mockUpdateNotifications.updateStream).thenAnswer(
      (_) => Stream<Set<String>>.fromIterable([]),
    );
    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<UpdateNotifications>()
          ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
          ..registerSingleton<EditorDb>(EditorDb(inMemoryDatabase: true))
          ..registerSingleton<EditorStateService>(EditorStateService());
      },
    );
    quillController = QuillController.basic();
  });

  tearDown(() async {
    quillController.dispose();
    await tearDownTestGetIt();
  });

  /// Container with the entry controller overridden and kept alive (the
  /// real editor page watches it; without a listener the autoDispose family
  /// recreates the notifier between frames and the animation-complete write
  /// lands on a discarded instance).
  ProviderContainer makeKeptAliveContainer({
    EntryController Function()? controllerFactory,
    List<Override> extraOverrides = const [],
  }) {
    final container = ProviderContainer(
      overrides: [
        entryControllerProvider(entryId).overrideWith(
          controllerFactory ?? _TestEntryController.new,
        ),
        ...extraOverrides,
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(
      entryControllerProvider(entryId),
      (_, _) {},
    );
    addTearDown(sub.close);
    return container;
  }

  // Quill widgets need FlutterQuillLocalizations.delegate, which the shared
  // makeTestableWidget helpers don't register — mirror the MaterialApp
  // wrapper used by editor_widget_test.
  Widget buildSubject(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        builder: LegacyMaterialBridge.builder,
        theme: resolveTestTheme(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
          FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: ToolbarWidget(
              controller: quillController,
              entryId: entryId,
            ),
          ),
        ),
      ),
    );
  }

  group('ToolbarWidget', () {
    testWidgets(
      'animates in, completes, and switches to the static path on rebuild',
      (tester) async {
        final container = makeKeptAliveContainer();
        final notifier = container.read(
          entryControllerProvider(entryId).notifier,
        );

        await tester.pumpWidget(buildSubject(container));
        await tester.pump();

        // Animation path: the toolbar mounts inside an Animate wrapper.
        expect(find.byType(QuillSimpleToolbar), findsOneWidget);
        final animate = tester.widget<Animate>(find.byType(Animate).first);
        expect(animate.onComplete, isNotNull);
        expect(notifier.animationCompleted, isFalse);

        // Fire the completion callback exactly as the animation controller
        // would; it must flip the notifier flag.
        final controller = AnimationController(vsync: const TestVSync());
        addTearDown(controller.dispose);
        animate.onComplete!(controller);
        expect(notifier.animationCompleted, isTrue);

        // Rebuild: the static branch renders a fixed-height SizedBox with
        // no Animate wrapper.
        await tester.pumpWidget(buildSubject(container));
        await tester.pump();

        expect(find.byType(Animate), findsNothing);
        final sizedBox = tester.widget<SizedBox>(
          find
              .ancestor(
                of: find.byType(QuillSimpleToolbar),
                matching: find.byType(SizedBox),
              )
              .first,
        );
        expect(sizedBox.height, ToolbarWidget.height);

        // Flush any timers Quill schedules internally before teardown.
        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets(
      'divider button in the more-formatting sheet inserts a divider embed',
      (tester) async {
        final container = makeKeptAliveContainer();
        // Render the static (post-animation) branch so the toolbar is at full
        // height and the buttons are hittable.
        container
                .read(entryControllerProvider(entryId).notifier)
                .animationCompleted =
            true;
        await tester.pumpWidget(buildSubject(container));
        await tester.pump();

        // The divider now lives behind the "…" overflow, not inline.
        expect(find.byIcon(LottiIcons.divider), findsNothing);
        await tester.tap(find.byIcon(LottiIcons.more));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.byIcon(LottiIcons.divider));
        await tester.pump();

        // The embed's object replacement character lands in the document.
        expect(
          quillController.document.toPlainText().codeUnitAt(0),
          0xFFFC,
        );

        // Flush any timers Quill schedules internally before teardown.
        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets(
      'save button is present, disabled while there is nothing to save',
      (tester) async {
        final container = makeKeptAliveContainer();
        container
                .read(entryControllerProvider(entryId).notifier)
                .animationCompleted =
            true;
        await tester.pumpWidget(buildSubject(container));
        await tester.pump();

        // The save action is pinned in the toolbar (not the footer) and, with a
        // freshly-loaded entry (no edits), renders disabled.
        expect(find.text('Save'), findsOneWidget);
        final saveButton = tester.widget<DesignSystemButton>(
          find.byType(DesignSystemButton),
        );
        expect(saveButton.onPressed, isNull);

        // Nothing to discard when clean: the discard control is absent (its slot
        // stays reserved, so the formatting controls don't shift).
        expect(find.byIcon(LottiIcons.close), findsNothing);

        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets(
      'wide layout shows the full set inline and drops the overflow button',
      (tester) async {
        // A wide surface puts the toolbar over the full-inline threshold.
        await tester.binding.setSurfaceSize(const Size(1400, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final container = makeKeptAliveContainer();
        container
                .read(entryControllerProvider(entryId).notifier)
                .animationCompleted =
            true;
        await tester.pumpWidget(buildSubject(container));
        await tester.pump();

        // Full inline: the divider lives in the toolbar (not behind "…"), and
        // the "…" overflow button is gone entirely.
        expect(find.byIcon(LottiIcons.more), findsNothing);
        expect(find.byIcon(LottiIcons.divider), findsOneWidget);

        // The inline divider inserts the embed (exercises the full config's
        // custom button).
        await tester.tap(find.byIcon(LottiIcons.divider));
        await tester.pump();
        expect(quillController.document.toPlainText().codeUnitAt(0), 0xFFFC);

        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets(
      'save button triggers save when there are unsaved changes',
      (tester) async {
        final saveSpy = _UnsavedSaveButtonController();
        final container = makeKeptAliveContainer(
          extraOverrides: [
            saveButtonControllerProvider(entryId).overrideWith(
              () => saveSpy,
            ),
          ],
        );
        container
                .read(entryControllerProvider(entryId).notifier)
                .animationCompleted =
            true;
        await tester.pumpWidget(buildSubject(container));
        await tester.pump();

        final saveButton = tester.widget<DesignSystemButton>(
          find.byType(DesignSystemButton),
        );
        expect(saveButton.onPressed, isNotNull);
        expect(saveSpy.saveCalled, isFalse);

        await tester.tap(find.text('Save'));
        await tester.pump();
        expect(saveSpy.saveCalled, isTrue);

        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets(
      'discard control appears when dirty and calls discard on the controller',
      (tester) async {
        final spy = _SpyEntryController();
        final container = makeKeptAliveContainer(
          controllerFactory: () => spy,
          extraOverrides: [
            saveButtonControllerProvider(entryId).overrideWith(
              _UnsavedSaveButtonController.new,
            ),
          ],
        );
        container
                .read(entryControllerProvider(entryId).notifier)
                .animationCompleted =
            true;
        await tester.pumpWidget(buildSubject(container));
        await tester.pump();

        // With unsaved changes the discard "X" is shown and the save button is
        // active.
        expect(find.byIcon(LottiIcons.close), findsOneWidget);
        final saveButton = tester.widget<DesignSystemButton>(
          find.byType(DesignSystemButton),
        );
        expect(saveButton.onPressed, isNotNull);

        // Tapping it routes to the controller's discard().
        expect(spy.discardCalled, isFalse);
        await tester.tap(find.byIcon(LottiIcons.close));
        await tester.pump();
        expect(spy.discardCalled, isTrue);

        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets(
      'an active list button paints its glyph against the fill, not into it',
      (tester) async {
        // Regression: Quill renders a toggled-on control as an
        // `IconButton.filled`, so the disc is already the accent. The toolbar
        // used to hand the glyph that same accent, which turned every active
        // control into a solid teal disc with no readable glyph.
        final container = makeKeptAliveContainer();
        container
                .read(entryControllerProvider(entryId).notifier)
                .animationCompleted =
            true;
        await tester.pumpWidget(buildSubject(container));
        await tester.pump();

        // Put the cursor inside a bulleted list so the list button goes active.
        quillController.formatSelection(Attribute.ul);
        await tester.pump();

        final button = tester.widget<legacy.IconButton>(
          find
              .ancestor(
                of: find.byIcon(Icons.format_list_bulleted),
                matching: find.byType(legacy.IconButton),
              )
              .first,
        );
        final style = button.style;
        expect(
          style,
          isNotNull,
          reason: 'the active button must carry an explicit selected style',
        );

        const active = <WidgetState>{};
        final fill = style!.backgroundColor?.resolve(active);
        final glyph = style.foregroundColor?.resolve(active);
        expect(fill, isNotNull);
        expect(glyph, isNotNull);

        // The actual defect: glyph and fill were the same colour.
        expect(
          glyph,
          isNot(fill),
          reason: 'an active glyph painted in its own fill colour is invisible',
        );

        // And they are far enough apart to actually read, not merely unequal.
        expect(
          _contrastRatio(glyph!, fill!),
          greaterThanOrEqualTo(4.5),
          reason: 'active glyph must clear WCAG AA against its fill',
        );

        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets(
      'the header control uses glyph buttons, never the clipping dropdown',
      (tester) async {
        // Regression: `HeaderStyleType.original` paints the word "Normal"
        // inside a fixed 44px icon button, so it clipped to "Nor" + a caret at
        // every toolbar width.
        await tester.binding.setSurfaceSize(const Size(1400, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final container = makeKeptAliveContainer();
        container
                .read(entryControllerProvider(entryId).notifier)
                .animationCompleted =
            true;
        await tester.pumpWidget(buildSubject(container));
        await tester.pump();

        // No word-label header control anywhere in the wide row...
        expect(find.text('Normal'), findsNothing);
        // ...and the compact glyph row is there instead.
        expect(find.text('N'), findsOneWidget);
        expect(find.text('H1'), findsOneWidget);
        expect(find.text('H2'), findsOneWidget);
        expect(find.text('H3'), findsOneWidget);

        // The glyphs are laid out at their natural size rather than clipped:
        // each fits inside the toolbar's 44px button box.
        final h1 = tester.getSize(find.text('H1'));
        expect(h1.width, lessThan(44));

        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets(
      'narrow toolbar moves the header control into the overflow sheet',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final container = makeKeptAliveContainer();
        container
                .read(entryControllerProvider(entryId).notifier)
                .animationCompleted =
            true;
        await tester.pumpWidget(buildSubject(container));
        await tester.pump();

        // Not inline on a phone-width bar — that is the width the crowded
        // toolbar was spending on a truncated label.
        expect(find.text('N'), findsNothing);
        expect(find.text('H1'), findsNothing);
        expect(find.text('Normal'), findsNothing);

        // It is reachable behind the "…" overflow instead.
        await tester.tap(find.byIcon(LottiIcons.more));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('H1'), findsOneWidget);
        expect(find.text('H2'), findsOneWidget);

        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets(
      'save collapses to icon-only on a narrow toolbar but keeps its name',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final container = makeKeptAliveContainer();
        container
                .read(entryControllerProvider(entryId).notifier)
                .animationCompleted =
            true;
        await tester.pumpWidget(buildSubject(container));
        await tester.pump();

        // The visible "Save" text is gone...
        expect(find.text('Save'), findsNothing);
        final saveButton = tester.widget<DesignSystemButton>(
          find.byType(DesignSystemButton),
        );
        expect(saveButton.label, isEmpty);
        // ...but the glyph and the accessible name both survive.
        expect(saveButton.leadingIcon, LottiIcons.save);
        expect(saveButton.semanticsLabel, 'Save');

        final compactWidth = tester
            .getSize(find.byType(DesignSystemButton))
            .width;

        // Widening past the breakpoint brings the label back — the collapse is
        // a width response, not a permanent downgrade.
        await tester.binding.setSurfaceSize(const Size(800, 600));
        await tester.pumpWidget(buildSubject(container));
        await tester.pump();

        expect(find.text('Save'), findsOneWidget);
        expect(
          tester.getSize(find.byType(DesignSystemButton)).width,
          greaterThan(compactWidth),
          reason: 'the labelled pill is the wider of the two states',
        );

        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets(
      'the trailing controls keep an accessible tap target when compact',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final container = makeKeptAliveContainer(
          extraOverrides: [
            saveButtonControllerProvider(entryId).overrideWith(
              _UnsavedSaveButtonController.new,
            ),
          ],
        );
        container
                .read(entryControllerProvider(entryId).notifier)
                .animationCompleted =
            true;
        await tester.pumpWidget(buildSubject(container));
        await tester.pump();

        // Shrinking the toolbar must not shrink the touch targets below the
        // 44px floor the rest of the row already uses.
        for (final icon in [LottiIcons.close, LottiIcons.more]) {
          final size = tester.getSize(
            find
                .ancestor(
                  of: find.byIcon(icon),
                  matching: find.byType(IconButton),
                )
                .first,
          );
          expect(size.width, greaterThanOrEqualTo(44));
          expect(size.height, greaterThanOrEqualTo(44));
        }

        await tester.pump(const Duration(seconds: 1));
      },
    );
  });
}

/// Relative luminance per WCAG 2.x, used to assert the active toolbar glyph is
/// genuinely legible against its fill rather than merely a different colour.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}
