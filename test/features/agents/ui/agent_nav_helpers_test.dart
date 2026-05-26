import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/agent_nav_helpers.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late MockNavService mockNav;
  late _RecordingBeamerDelegate mockDelegate;

  setUp(() {
    mockNav = MockNavService();
    mockDelegate = _RecordingBeamerDelegate();
    if (getIt.isRegistered<NavService>()) {
      getIt.unregister<NavService>();
    }
    getIt.registerSingleton<NavService>(mockNav);
  });

  tearDown(() {
    if (getIt.isRegistered<NavService>()) {
      getIt.unregister<NavService>();
    }
  });

  group('agentInstanceRoute', () {
    test('renders the canonical /settings/agents/instances/<id> path', () {
      expect(
        agentInstanceRoute('agent-42'),
        '/settings/agents/instances/agent-42',
      );
    });
  });

  group('navigateBackFromAgent', () {
    testWidgets(
      'beams back via the NavService when sitting on a settings/agents path',
      (tester) async {
        when(
          () => mockNav.currentPath,
        ).thenReturn('/settings/agents/instances/agent-1');
        when(() => mockNav.beamBack()).thenReturn(null);

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => navigateBackFromAgent(context),
                child: const Text('back'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('back'));
        await tester.pump();

        verify(() => mockNav.beamBack()).called(1);
      },
    );

    testWidgets(
      'falls back to Navigator.pop when not on a settings/agents path',
      (tester) async {
        when(() => mockNav.currentPath).thenReturn('/tasks');

        var popped = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (rootContext) => TextButton(
                onPressed: () async {
                  popped =
                      await Navigator.of(rootContext).push<bool>(
                        MaterialPageRoute<bool>(
                          builder: (pushedContext) => TextButton(
                            onPressed: () => navigateBackFromAgent(
                              pushedContext,
                            ),
                            child: const Text('back'),
                          ),
                        ),
                      ) ??
                      false;
                },
                child: const Text('open'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('back'));
        await tester.pumpAndSettle();

        // Navigator popped the pushed route — `back` is gone again.
        expect(find.text('back'), findsNothing);
        verifyNever(() => mockNav.beamBack());
        // popped stays false (we didn't return a value via pop).
        expect(popped, isFalse);
      },
    );
  });

  group('navigateToAgentInstance', () {
    test(
      'switches to the Settings tab when not already there, beams the '
      'delegate, and persists the route',
      () async {
        when(() => mockNav.index).thenReturn(0);
        when(() => mockNav.settingsIndex).thenReturn(5);
        when(() => mockNav.setIndex(any())).thenReturn(null);
        when(() => mockNav.settingsDelegate).thenReturn(mockDelegate);
        when(
          () => mockNav.persistNamedRoute(any()),
        ).thenAnswer((_) async {});

        navigateToAgentInstance('agent-99');
        // persistNamedRoute is fire-and-forget; flush the microtask queue.
        await Future<void>.delayed(Duration.zero);

        verify(() => mockNav.setIndex(5)).called(1);
        expect(mockDelegate.beamed, [
          '/settings/agents/instances/agent-99',
        ]);
        verify(
          () => mockNav.persistNamedRoute(
            '/settings/agents/instances/agent-99',
          ),
        ).called(1);
      },
    );

    test(
      'skips setIndex when already on the Settings tab so in-tab Beamer '
      'history is preserved',
      () async {
        when(() => mockNav.index).thenReturn(5);
        when(() => mockNav.settingsIndex).thenReturn(5);
        when(() => mockNav.settingsDelegate).thenReturn(mockDelegate);
        when(
          () => mockNav.persistNamedRoute(any()),
        ).thenAnswer((_) async {});

        navigateToAgentInstance('agent-stay');
        await Future<void>.delayed(Duration.zero);

        verifyNever(() => mockNav.setIndex(any()));
        expect(mockDelegate.beamed, [
          '/settings/agents/instances/agent-stay',
        ]);
        verify(
          () => mockNav.persistNamedRoute(
            '/settings/agents/instances/agent-stay',
          ),
        ).called(1);
      },
    );
  });

  group('agentBackButton', () {
    Widget buildHost({VoidCallback? onPressed}) => MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        appBar: AppBar(
          leading: Builder(
            builder: (context) =>
                agentBackButton(context, onPressed: onPressed),
          ),
        ),
      ),
    );

    testWidgets('uses the localized back-button tooltip', (tester) async {
      await tester.pumpWidget(buildHost(onPressed: () {}));
      final iconButton = tester.widget<IconButton>(
        find.byType(IconButton),
      );
      expect(iconButton.tooltip, isNotEmpty);
      // chevron icon at size 30.
      final icon = iconButton.icon as Icon;
      expect(icon.icon, Icons.chevron_left);
      expect(icon.size, 30);
    });

    testWidgets(
      'invokes the provided onPressed override instead of the default',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(buildHost(onPressed: () => taps++));

        await tester.tap(find.byType(IconButton));
        await tester.pump();

        expect(taps, 1);
        verifyNever(() => mockNav.beamBack());
      },
    );

    testWidgets(
      'default onPressed delegates to navigateBackFromAgent',
      (tester) async {
        when(
          () => mockNav.currentPath,
        ).thenReturn('/settings/agents/templates');
        when(() => mockNav.beamBack()).thenReturn(null);

        await tester.pumpWidget(buildHost());

        await tester.tap(find.byType(IconButton));
        await tester.pump();

        verify(() => mockNav.beamBack()).called(1);
      },
    );
  });
}

class _RecordingBeamerDelegate extends BeamerDelegate {
  _RecordingBeamerDelegate()
    : super(
        locationBuilder: RoutesLocationBuilder(
          routes: {'*': (_, _, _) => const SizedBox.shrink()},
        ).call,
      );

  final List<String> beamed = <String>[];

  @override
  void beamToNamed(
    String uri, {
    Object? data,
    Object? routeState,
    bool beamBackOnPop = false,
    bool popBeamLocationOnPop = false,
    bool stacked = true,
    bool replaceRouteInformation = false,
    TransitionDelegate<dynamic>? transitionDelegate,
    String? popToNamed,
  }) {
    beamed.add(uri);
  }
}
