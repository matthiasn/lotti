import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/markdown_link_utils.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../mocks/mocks.dart';

Future<void> _pumpMarkdownLink(
  WidgetTester tester, {
  required String text,
  required String url,
  TextStyle style = const TextStyle(fontSize: 14),
  Color? linkColor,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return buildMarkdownLink(
              context,
              TextSpan(text: text),
              url,
              style,
              linkColor: linkColor,
            );
          },
        ),
      ),
    ),
  );
}

void main() {
  group('handleMarkdownLinkTap', () {
    late MockUrlLauncher mockUrlLauncher;
    late UrlLauncherPlatform originalInstance;

    setUp(() {
      originalInstance = UrlLauncherPlatform.instance;
      mockUrlLauncher = MockUrlLauncher();
      UrlLauncherPlatform.instance = mockUrlLauncher;
      registerFallbackValue(FakeLaunchOptions());
    });

    tearDown(() {
      UrlLauncherPlatform.instance = originalInstance;
    });

    test('launches valid URL externally', () async {
      when(
        () => mockUrlLauncher.launchUrl(any(), any()),
      ).thenAnswer((_) async => true);

      await handleMarkdownLinkTap('https://example.com', 'Example');

      verify(
        () => mockUrlLauncher.launchUrl(
          'https://example.com',
          any(),
        ),
      ).called(1);
    });

    test('does not launch when URL is empty', () async {
      await handleMarkdownLinkTap('', '');

      verifyNever(() => mockUrlLauncher.launchUrl(any(), any()));
    });

    test('does not launch when URL has no scheme', () async {
      await handleMarkdownLinkTap('example.com/path', '');

      verifyNever(() => mockUrlLauncher.launchUrl(any(), any()));
    });

    test('routes app-local task paths through NavService', () async {
      getIt.pushNewScope();
      final mockNavService = MockNavService();
      getIt.registerSingleton<NavService>(mockNavService);
      addTearDown(() async {
        await getIt.resetScope();
        await getIt.popScope();
      });

      await handleMarkdownLinkTap('/tasks/task-123', 'Task');

      verify(() => mockNavService.beamToNamed('/tasks/task-123')).called(1);
      verifyNever(() => mockUrlLauncher.launchUrl(any(), any()));
    });

    test('ignores bare relative paths instead of routing them', () async {
      getIt.pushNewScope();
      final mockNavService = MockNavService();
      getIt.registerSingleton<NavService>(mockNavService);
      addTearDown(() async {
        await getIt.resetScope();
        await getIt.popScope();
      });

      await handleMarkdownLinkTap('tasks/task-123', 'Task');

      verifyNever(() => mockNavService.beamToNamed(any()));
      verifyNever(() => mockUrlLauncher.launchUrl(any(), any()));
    });

    test('routes lotti task URLs through NavService', () async {
      getIt.pushNewScope();
      final mockNavService = MockNavService();
      getIt.registerSingleton<NavService>(mockNavService);
      addTearDown(() async {
        await getIt.resetScope();
        await getIt.popScope();
      });

      await handleMarkdownLinkTap('lotti://tasks/task-456', 'Task');

      verify(() => mockNavService.beamToNamed('/tasks/task-456')).called(1);
      verifyNever(() => mockUrlLauncher.launchUrl(any(), any()));
    });

    test(
      'routes lotti URLs with a path but no host through NavService',
      () async {
        getIt.pushNewScope();
        final mockNavService = MockNavService();
        getIt.registerSingleton<NavService>(mockNavService);
        addTearDown(() async {
          await getIt.resetScope();
          await getIt.popScope();
        });

        await handleMarkdownLinkTap('lotti:/tasks/task-789', 'Task');

        verify(() => mockNavService.beamToNamed('/tasks/task-789')).called(1);
        verifyNever(() => mockUrlLauncher.launchUrl(any(), any()));
      },
    );

    test('handles URL with special characters', () async {
      when(
        () => mockUrlLauncher.launchUrl(any(), any()),
      ).thenAnswer((_) async => true);

      await handleMarkdownLinkTap(
        'https://example.com/path?q=hello%20world&lang=en',
        'Search',
      );

      verify(
        () => mockUrlLauncher.launchUrl(
          'https://example.com/path?q=hello%20world&lang=en',
          any(),
        ),
      ).called(1);
    });

    glados.Glados(
      glados.any.generatedInternalMarkdownRoute,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'routes generated app-local markdown URLs through NavService',
      (scenario) async {
        getIt.pushNewScope();
        final mockNavService = MockNavService();
        getIt.registerSingleton<NavService>(mockNavService);

        try {
          await handleMarkdownLinkTap(scenario.url, 'Generated');

          verify(
            () => mockNavService.beamToNamed(scenario.expectedRoute),
          ).called(1);
          verifyNever(() => mockUrlLauncher.launchUrl(any(), any()));
        } finally {
          await getIt.resetScope();
          await getIt.popScope();
        }
      },
      tags: 'glados',
    );
  });

  group('buildMarkdownLink', () {
    testWidgets('renders link with correct styling', (tester) async {
      await _pumpMarkdownLink(
        tester,
        text: 'Click here',
        url: 'https://example.com',
      );

      expect(find.text('Click here'), findsOneWidget);

      final inkWell = tester.widget<InkWell>(find.byType(InkWell));
      expect(inkWell.mouseCursor, SystemMouseCursors.click);
    });

    testWidgets('applies custom link color', (tester) async {
      const customColor = Colors.red;

      await _pumpMarkdownLink(
        tester,
        text: 'Red link',
        url: 'https://example.com',
        linkColor: customColor,
      );

      final textWidget = tester.widget<Text>(find.byType(Text));
      final span = textWidget.textSpan! as TextSpan;
      expect(span.style!.color, customColor);
      expect(span.style!.decoration, TextDecoration.underline);
      expect(span.style!.decorationColor, customColor);
    });

    testWidgets('uses theme primary color when no linkColor specified', (
      tester,
    ) async {
      await _pumpMarkdownLink(
        tester,
        text: 'Default link',
        url: 'https://example.com',
      );

      final textWidget = tester.widget<Text>(find.byType(Text));
      final span = textWidget.textSpan! as TextSpan;
      expect(span.style!.color, isNotNull);
      expect(span.style!.decoration, TextDecoration.underline);
    });

    testWidgets('has Semantics with link: true', (tester) async {
      await _pumpMarkdownLink(
        tester,
        text: 'Accessible link',
        url: 'https://example.com',
      );

      final semanticsWidgets = tester.widgetList<Semantics>(
        find.byType(Semantics),
      );
      final linkSemantics = semanticsWidgets.where(
        (s) => s.properties.link == true,
      );
      expect(linkSemantics, isNotEmpty);
    });

    testWidgets('tapping InkWell triggers URL launch', (tester) async {
      final mockUrlLauncher = MockUrlLauncher();
      final originalInstance = UrlLauncherPlatform.instance;
      UrlLauncherPlatform.instance = mockUrlLauncher;
      registerFallbackValue(FakeLaunchOptions());

      when(
        () => mockUrlLauncher.launchUrl(any(), any()),
      ).thenAnswer((_) async => true);

      addTearDown(() {
        UrlLauncherPlatform.instance = originalInstance;
      });

      await _pumpMarkdownLink(
        tester,
        text: 'Tap me',
        url: 'https://example.com',
      );

      await tester.tap(find.byType(InkWell));
      await tester.pump();

      verify(
        () => mockUrlLauncher.launchUrl('https://example.com', any()),
      ).called(1);
    });

    testWidgets('tapping app-local task link routes inside the app', (
      tester,
    ) async {
      getIt.pushNewScope();
      final mockNavService = MockNavService();
      getIt.registerSingleton<NavService>(mockNavService);
      addTearDown(() async {
        await getIt.resetScope();
        await getIt.popScope();
      });

      await _pumpMarkdownLink(
        tester,
        text: 'Open task',
        url: '/tasks/task-789',
      );

      await tester.tap(find.byType(InkWell));
      await tester.pump();

      verify(() => mockNavService.beamToNamed('/tasks/task-789')).called(1);
    });
  });
}

enum _GeneratedMarkdownRouteRoot {
  calendar,
  dashboards,
  habits,
  journal,
  projects,
  settings,
  tasks,
}

enum _GeneratedMarkdownRouteShape {
  absolutePath,
  lottiHost,
  lottiPath,
}

enum _GeneratedMarkdownPathSegment {
  alpha,
  numeric,
  dashed,
  underscored,
}

enum _GeneratedMarkdownQueryValue {
  none,
  alpha,
  encodedSpace,
  numeric,
}

class _GeneratedInternalMarkdownRoute {
  const _GeneratedInternalMarkdownRoute({
    required this.root,
    required this.shape,
    required this.segments,
    required this.queryValue,
  });

  final _GeneratedMarkdownRouteRoot root;
  final _GeneratedMarkdownRouteShape shape;
  final List<_GeneratedMarkdownPathSegment> segments;
  final _GeneratedMarkdownQueryValue queryValue;

  String get path {
    final suffix = segments.isEmpty
        ? ''
        : '/${segments.map((segment) => segment.text).join('/')}';
    return '${root.path}$suffix';
  }

  String get query => switch (queryValue) {
    _GeneratedMarkdownQueryValue.none => '',
    _GeneratedMarkdownQueryValue.alpha => 'q=alpha',
    _GeneratedMarkdownQueryValue.encodedSpace => 'q=hello%20world',
    _GeneratedMarkdownQueryValue.numeric => 'page=2',
  };

  String get expectedRoute => query.isEmpty ? path : '$path?$query';

  String get url {
    final withQuery = query.isEmpty ? path : '$path?$query';
    return switch (shape) {
      _GeneratedMarkdownRouteShape.absolutePath => withQuery,
      _GeneratedMarkdownRouteShape.lottiHost =>
        'lotti://${withQuery.substring(1)}',
      _GeneratedMarkdownRouteShape.lottiPath => 'lotti:$withQuery',
    };
  }

  @override
  String toString() {
    return '_GeneratedInternalMarkdownRoute('
        'url: $url, '
        'expectedRoute: $expectedRoute)';
  }
}

extension on _GeneratedMarkdownRouteRoot {
  String get path => switch (this) {
    _GeneratedMarkdownRouteRoot.calendar => '/calendar',
    _GeneratedMarkdownRouteRoot.dashboards => '/dashboards',
    _GeneratedMarkdownRouteRoot.habits => '/habits',
    _GeneratedMarkdownRouteRoot.journal => '/journal',
    _GeneratedMarkdownRouteRoot.projects => '/projects',
    _GeneratedMarkdownRouteRoot.settings => '/settings',
    _GeneratedMarkdownRouteRoot.tasks => '/tasks',
  };
}

extension on _GeneratedMarkdownPathSegment {
  String get text => switch (this) {
    _GeneratedMarkdownPathSegment.alpha => 'alpha',
    _GeneratedMarkdownPathSegment.numeric => '2024',
    _GeneratedMarkdownPathSegment.dashed => 'dash-name',
    _GeneratedMarkdownPathSegment.underscored => 'under_score',
  };
}

extension _AnyMarkdownLinkUtils on glados.Any {
  glados.Generator<_GeneratedMarkdownRouteRoot> get _routeRoot =>
      glados.AnyUtils(this).choose(_GeneratedMarkdownRouteRoot.values);

  glados.Generator<_GeneratedMarkdownRouteShape> get _routeShape =>
      glados.AnyUtils(this).choose(_GeneratedMarkdownRouteShape.values);

  glados.Generator<_GeneratedMarkdownPathSegment> get _pathSegment =>
      glados.AnyUtils(this).choose(_GeneratedMarkdownPathSegment.values);

  glados.Generator<_GeneratedMarkdownQueryValue> get _queryValue =>
      glados.AnyUtils(this).choose(_GeneratedMarkdownQueryValue.values);

  glados.Generator<_GeneratedInternalMarkdownRoute>
  get generatedInternalMarkdownRoute => glados.CombinableAny(this).combine4(
    _routeRoot,
    _routeShape,
    glados.ListAnys(this).listWithLengthInRange(0, 3, _pathSegment),
    _queryValue,
    (
      _GeneratedMarkdownRouteRoot root,
      _GeneratedMarkdownRouteShape shape,
      List<_GeneratedMarkdownPathSegment> segments,
      _GeneratedMarkdownQueryValue queryValue,
    ) => _GeneratedInternalMarkdownRoute(
      root: root,
      shape: shape,
      segments: segments,
      queryValue: queryValue,
    ),
  );
}
