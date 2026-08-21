import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/keyboard/ui/list_detail_focus_traversal.dart';
import 'package:lotti/features/tasks/ui/widgets/task_detail_back_leading.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/app_bar/glass_action_button.dart';
import 'package:lotti/widgets/app_bar/glass_back_button.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  late MockNavService mockNavService;
  late ValueNotifier<List<String>> stack;

  setUp(() async {
    mockNavService = MockNavService();
    stack = ValueNotifier<List<String>>(const <String>[]);
    when(() => mockNavService.desktopTaskDetailStack).thenReturn(stack);

    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<NavService>(mockNavService);
      },
    );
  });

  tearDown(() async {
    stack.dispose();
    await tearDownTestGetIt();
  });

  Future<void> pumpLeading(WidgetTester tester) => tester.pumpWidget(
    makeTestableWidgetWithScaffold(const TaskDetailDesktopBackLeading()),
  );

  group('TaskDetailDesktopBackLeading', () {
    testWidgets('hides the button while at most one task is stacked', (
      tester,
    ) async {
      await pumpLeading(tester);
      expect(find.byType(GlassBackButton), findsNothing);

      stack.value = const ['base-task'];
      await tester.pump();
      expect(find.byType(GlassBackButton), findsNothing);
    });

    testWidgets('shows the button for a layered linked task and pops on tap', (
      tester,
    ) async {
      stack.value = const ['base-task', 'linked-task'];
      await pumpLeading(tester);

      expect(find.byType(GlassBackButton), findsOneWidget);

      await tester.tap(find.byType(GlassBackButton));
      verify(() => mockNavService.popDesktopTaskDetail()).called(1);
    });

    testWidgets('reacts to stack pushes and pops', (tester) async {
      stack.value = const ['base-task'];
      await pumpLeading(tester);
      expect(find.byType(GlassBackButton), findsNothing);

      // A linked task gets layered on top — the back affordance appears.
      stack.value = const ['base-task', 'linked-task'];
      await tester.pump();
      expect(find.byType(GlassBackButton), findsOneWidget);

      // Back at the base task — the arrow disappears again.
      stack.value = const ['base-task'];
      await tester.pump();
      expect(find.byType(GlassBackButton), findsNothing);
    });
  });

  testWidgets('TaskDetailShowListButton exposes its action and label', (
    tester,
  ) async {
    var presses = 0;
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        TaskDetailShowListButton(onPressed: () => presses++),
      ),
    );

    expect(find.byTooltip('Show list'), findsOneWidget);
    final semanticsFinder = find.bySemanticsLabel('Show list');
    expect(semanticsFinder, findsOneWidget);
    final semantics = tester.getSemantics(semanticsFinder);
    expect(semantics.label, 'Show list');
    expect(
      semantics.getSemanticsData().hasAction(ui.SemanticsAction.tap),
      isTrue,
    );
    await tester.tap(find.byType(GlassActionButton));
    expect(presses, 1);
  });

  testWidgets('TaskDetailShowListButton keeps light ink in the dark theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        TaskDetailShowListButton(onPressed: () {}),
        theme: DesignSystemTheme.dark(),
      ),
    );

    expect(
      tester.widget<Icon>(find.byIcon(LottiIcons.sidebar)).color,
      dsTokensDark.colors.text.highEmphasis,
    );
  });

  group('TaskDetailHideListButton', () {
    /// Mounts the button inside a split whose panes are stand-ins: only the
    /// scope's two flags and its visibility callback matter here.
    Future<List<bool>> pumpSplit(
      WidgetTester tester, {
      required bool listPaneVisible,
      required bool canHideListPane,
    }) async {
      final visibilityChanges = <bool>[];
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ListDetailFocusTraversal(
            debugLabel: 'test-split',
            listPaneVisible: listPaneVisible,
            canHideListPane: canHideListPane,
            onListPaneVisibilityChanged: visibilityChanges.add,
            listPane: const SizedBox(width: 100),
            divider: const SizedBox(width: 4),
            detailPane: const Align(
              alignment: Alignment.topLeft,
              child: TaskDetailHideListButton(),
            ),
          ),
        ),
      );
      await tester.pump();
      return visibilityChanges;
    }

    testWidgets('hides the list pane on tap', (tester) async {
      final changes = await pumpSplit(
        tester,
        listPaneVisible: true,
        canHideListPane: true,
      );

      await tester.tap(find.byKey(const ValueKey('tasks-hide-list-pane')));
      await tester.pump();

      expect(changes, [false]);
    });

    testWidgets('stands down where hiding the list is not offered', (
      tester,
    ) async {
      await pumpSplit(
        tester,
        listPaneVisible: true,
        canHideListPane: false,
      );
      expect(find.byKey(const ValueKey('tasks-hide-list-pane')), findsNothing);

      // Already hidden: the show button owns that corner instead.
      await pumpSplit(
        tester,
        listPaneVisible: false,
        canHideListPane: true,
      );
      expect(find.byKey(const ValueKey('tasks-hide-list-pane')), findsNothing);
    });

    testWidgets('renders nothing outside a split layout, as on mobile', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const TaskDetailHideListButton()),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('tasks-hide-list-pane')), findsNothing);
    });

    testWidgets(
      'the glyph sits on the leading edge of its tap target, so it stacks on '
      'the header rail rather than a padding-width inboard of it',
      (tester) async {
        await pumpSplit(
          tester,
          listPaneVisible: true,
          canHideListPane: true,
        );

        final button = find.byKey(const ValueKey('tasks-hide-list-pane'));
        final glyph = find.descendant(of: button, matching: find.byType(Icon));
        expect(
          tester.getTopLeft(glyph).dx,
          closeTo(tester.getTopLeft(button).dx, 0.5),
        );
        // Still a full tap target, not a shrink-wrapped glyph.
        expect(
          tester.getSize(button),
          const Size.square(TapTargets.minimum),
        );
      },
    );
  });
}
