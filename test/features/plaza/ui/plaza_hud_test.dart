import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/plaza/ui/debug_overlay.dart';
import 'package:lotti/features/plaza/ui/plaza_hud.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  late int walks;
  late int overviews;
  late int homes;
  late int exits;
  late PlazaFrameRate frameRate;
  late bool showDebug;
  late bool showPenguins;
  late bool showMeerkats;
  late bool showConnections;

  setUp(() {
    walks = 0;
    overviews = 0;
    homes = 0;
    exits = 0;
    frameRate = PlazaFrameRate.sixty;
    showDebug = false;
    showPenguins = true;
    showMeerkats = true;
    showConnections = true;
  });

  Widget host({
    String? toast,
    String? walkChip,
    bool isCategory = false,
    bool penguinsAvailable = true,
    bool meerkatsAvailable = true,
    bool connectionsAvailable = false,
  }) => makeTestableWidget2(
    Scaffold(
      body: PlazaHud(
        projectLabel: 'Project Waddle',
        taskCount: 28,
        weekCount: 6,
        isCategory: isCategory,
        attentionCount: 4,
        onMorningWalk: () => walks++,
        onOverview: () => overviews++,
        onHome: () => homes++,
        onExit: () => exits++,
        frameRate: frameRate,
        onFrameRateChanged: (rate) => frameRate = rate,
        showMeerkats: showMeerkats,
        onShowMeerkatsChanged: meerkatsAvailable
            ? (show) => showMeerkats = show
            : null,
        showPenguins: showPenguins,
        onShowPenguinsChanged: penguinsAvailable
            ? (show) => showPenguins = show
            : null,
        showDebug: showDebug,
        onShowDebugChanged: (show) => showDebug = show,
        showConnections: showConnections,
        onShowConnectionsChanged: connectionsAvailable
            ? (show) => showConnections = show
            : null,
        toast: toast,
        walkChip: walkChip,
      ),
    ),
    mediaQueryData: const MediaQueryData(size: Size(1400, 900)),
  );

  testWidgets(
    'penguin option updates both ways and disables when unavailable',
    (tester) async {
      DesignSystemCheckbox control() => tester.widget<DesignSystemCheckbox>(
        find.ancestor(
          of: find.text('Penguins'),
          matching: find.byType(DesignSystemCheckbox),
        ),
      );
      await tester.pumpWidget(host());
      expect(control().value, isTrue);
      await tester.tap(find.text('Penguins'));
      expect(showPenguins, isFalse);
      await tester.pumpWidget(host());
      expect(control().value, isFalse);
      await tester.tap(find.text('Penguins'));
      expect(showPenguins, isTrue);
      await tester.pumpWidget(host(penguinsAvailable: false));
      expect(control().onChanged, isNull);
      await tester.tap(find.text('Penguins'));
      expect(showPenguins, isTrue);
    },
  );

  testWidgets('connections toggle is reversible and absent without links', (
    tester,
  ) async {
    await tester.pumpWidget(host(connectionsAvailable: true));
    await tester.tap(find.text('Connections'));
    expect(showConnections, isFalse);
    expect(showPenguins, isTrue);
    await tester.pumpWidget(host(connectionsAvailable: true));
    final control = tester.widget<DesignSystemCheckbox>(
      find.ancestor(
        of: find.text('Connections'),
        matching: find.byType(DesignSystemCheckbox),
      ),
    );
    expect(control.value, isFalse);
    await tester.tap(find.text('Connections'));
    expect(showConnections, isTrue);
    await tester.pumpWidget(host());
    expect(find.text('Connections'), findsNothing);
  });

  testWidgets('shows the project, the counts and the legends', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(host());
    expect(find.text('Project Waddle — Plaza'), findsOneWidget);
    expect(find.text('28 tasks · 6 weeks · 4 need attention'), findsOneWidget);
    expect(
      find.textContaining('WASD walk · hold Shift: 8× speed'),
      findsOneWidget,
    );
    for (final state in ['In Progress', 'Open', 'Blocked', 'Overdue', 'Done']) {
      expect(find.text(state), findsOneWidget);
    }
    final done = tester.widget<DsPill>(
      find.ancestor(
        of: find.text('Done'),
        matching: find.byType(DsPill),
      ),
    );
    final context = tester.element(find.text('Done'));
    expect(done.color, context.designTokens.colors.alert.success.defaultColor);
  });

  testWidgets('category totals count projects without fictitious task weeks', (
    tester,
  ) async {
    await tester.pumpWidget(host(isCategory: true));
    expect(find.text('28 projects · 4 need attention'), findsOneWidget);
    expect(find.textContaining('6 weeks'), findsNothing);
  });

  testWidgets('the three buttons fire their callbacks', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(host());
    await tester.tap(find.text('Morning walk'));
    await tester.tap(find.text('Overview'));
    await tester.tap(find.text('Home'));
    await tester.tap(find.text('Back'));
    expect((walks, overviews, homes), (1, 1, 1));
    expect(exits, 1);
  });

  testWidgets('toast and walk chip appear only when set', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(host());
    expect(find.text('Fuel the shuttle'), findsNothing);
    await tester.pumpWidget(
      host(toast: 'Fuel the shuttle', walkChip: 'Morning walk · stop 2 of 5'),
    );
    expect(find.text('Fuel the shuttle'), findsOneWidget);
    expect(find.text('Morning walk · stop 2 of 5'), findsOneWidget);
    // Neither blocks the world underneath.
    expect(
      find.ancestor(
        of: find.text('Fuel the shuttle'),
        matching: find.byType(IgnorePointer),
      ),
      findsWidgets,
    );
  });

  testWidgets('the frame-rate control and the debug box drive the harness', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(host());
    // Each segment draws its label twice: once visible, once as the ghost
    // that reserves the selected width.
    expect(find.text('auto'), findsNWidgets(2));
    expect(find.text('60'), findsNWidgets(2));
    await tester.tap(find.text('30').hitTestable().first);
    await tester.pump();
    expect(frameRate, PlazaFrameRate.thirty);
    await tester.tap(find.text('auto').hitTestable().first);
    await tester.pump();
    expect(frameRate, PlazaFrameRate.auto);
    expect(showDebug, isFalse);
    await tester.tap(find.text('Debug'));
    await tester.pump();
    expect(showDebug, isTrue);
  });

  testWidgets('each species checkbox changes only its own visibility', (
    tester,
  ) async {
    bool checked(String label) => tester
        .widget<DesignSystemCheckbox>(
          find.byWidgetPredicate(
            (w) => w is DesignSystemCheckbox && w.label == label,
          ),
        )
        .value!;
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(host());
    expect(checked('Penguins'), isTrue);
    expect(checked('Meerkats'), isTrue);
    await tester.tap(find.text('Penguins'));
    await tester.pumpWidget(host());
    expect(checked('Penguins'), isFalse);
    expect(checked('Meerkats'), isTrue);
    await tester.tap(find.text('Meerkats'));
    await tester.pumpWidget(host());
    expect((showPenguins, showMeerkats), (false, false));
    await tester.tap(find.text('Penguins'));
    await tester.pumpWidget(host());
    expect(checked('Penguins'), isTrue);
    expect(checked('Meerkats'), isFalse);
    expect(showDebug, isFalse);
    await tester.pumpWidget(host(meerkatsAvailable: false));
    final disabled = tester.widget<DesignSystemCheckbox>(
      find.byWidgetPredicate(
        (w) => w is DesignSystemCheckbox && w.label == 'Meerkats',
      ),
    );
    expect(disabled.onChanged, isNull);
    await tester.tap(find.text('Meerkats'));
    expect(showMeerkats, isFalse);
  });
}
