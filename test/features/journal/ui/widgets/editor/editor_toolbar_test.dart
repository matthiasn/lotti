import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/save_button_controller.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_toolbar.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';

class _TestEntryController extends EntryController {
  @override
  Future<EntryState?> build({required String id}) async {
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
/// teal save + the discard "X") render regardless of the entry's real state.
class _UnsavedSaveButtonController extends SaveButtonController {
  @override
  Future<bool?> build({required String id}) async => true;
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
        entryControllerProvider(id: entryId).overrideWith(
          controllerFactory ?? _TestEntryController.new,
        ),
        ...extraOverrides,
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(
      entryControllerProvider(id: entryId),
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
        theme: resolveTestTheme(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
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
          entryControllerProvider(id: entryId).notifier,
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
                .read(entryControllerProvider(id: entryId).notifier)
                .animationCompleted =
            true;
        await tester.pumpWidget(buildSubject(container));
        await tester.pump();

        // The divider now lives behind the "…" overflow, not inline.
        expect(find.byIcon(Icons.horizontal_rule), findsNothing);
        await tester.tap(find.byIcon(Icons.more_horiz));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.byIcon(Icons.horizontal_rule));
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
                .read(entryControllerProvider(id: entryId).notifier)
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
        expect(find.byIcon(Icons.close_rounded), findsNothing);

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
            saveButtonControllerProvider(id: entryId).overrideWith(
              _UnsavedSaveButtonController.new,
            ),
          ],
        );
        container
                .read(entryControllerProvider(id: entryId).notifier)
                .animationCompleted =
            true;
        await tester.pumpWidget(buildSubject(container));
        await tester.pump();

        // With unsaved changes the discard "X" is shown and the save button is
        // active.
        expect(find.byIcon(Icons.close_rounded), findsOneWidget);
        final saveButton = tester.widget<DesignSystemButton>(
          find.byType(DesignSystemButton),
        );
        expect(saveButton.onPressed, isNotNull);

        // Tapping it routes to the controller's discard().
        expect(spy.discardCalled, isFalse);
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pump();
        expect(spy.discardCalled, isTrue);

        await tester.pump(const Duration(seconds: 1));
      },
    );
  });
}
