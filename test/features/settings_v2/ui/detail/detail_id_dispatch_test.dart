import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings_v2/ui/detail/detail_id_dispatch.dart';
import 'package:lotti/services/nav_service.dart';

/// Builds a route record the way `SettingsLocation.buildPages` does on
/// desktop: the raw path plus whatever Beamer matched into
/// `pathParameters`.
DesktopSettingsRoute _route(
  String path, {
  Map<String, String> pathParameters = const {},
}) => (
  path: path,
  pathParameters: pathParameters,
  queryParameters: const {},
);

void main() {
  const templatesUrl = '/settings/agents/templates';

  late ValueNotifier<DesktopSettingsRoute?> routes;

  setUp(() {
    routes = ValueNotifier<DesktopSettingsRoute?>(null);
  });
  tearDown(() => routes.dispose());

  Future<void> pump(
    WidgetTester tester, {
    Map<String, Widget Function(BuildContext, String)> detailSubRoutes =
        const {},
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DetailIdDispatch(
          idParamKey: 'templateId',
          listenable: routes,
          list: (_) => const Text('list'),
          create: (_, _) => const Text('create'),
          detail: (_, id) => Text('detail:$id'),
          detailSubRoutes: detailSubRoutes,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Map<String, Widget Function(BuildContext, String)> reviewRoute() => {
    'review': (_, id) => Text('review:$id'),
  };

  group('DetailIdDispatch — branch selection', () {
    testWidgets('bare branch URL renders the list', (tester) async {
      routes.value = _route(templatesUrl);
      await pump(tester);

      expect(find.text('list'), findsOneWidget);
    });

    testWidgets('a /create URL renders the create body even though Beamer '
        'hands back `create` as the id', (tester) async {
      routes.value = _route(
        '$templatesUrl/create',
        pathParameters: const {'templateId': 'create'},
      );
      await pump(tester);

      expect(find.text('create'), findsOneWidget);
    });

    testWidgets('an id URL renders the detail body with that id', (
      tester,
    ) async {
      routes.value = _route(
        '$templatesUrl/t1',
        pathParameters: const {'templateId': 't1'},
      );
      await pump(tester);

      expect(find.text('detail:t1'), findsOneWidget);
    });
  });

  group('DetailIdDispatch — detail sub-routes', () {
    testWidgets(
      'a registered trailing segment wins over the detail body — the '
      'regression that made the one-on-one unreachable on desktop',
      (tester) async {
        routes.value = _route(
          '$templatesUrl/t1/review',
          pathParameters: const {'templateId': 't1'},
        );
        await pump(tester, detailSubRoutes: reviewRoute());

        expect(find.text('review:t1'), findsOneWidget);
        expect(find.text('detail:t1'), findsNothing);
      },
    );

    testWidgets('the same URL falls through to detail when nothing is '
        'registered, so an unknown segment still shows the entity', (
      tester,
    ) async {
      routes.value = _route(
        '$templatesUrl/t1/review',
        pathParameters: const {'templateId': 't1'},
      );
      await pump(tester);

      expect(find.text('detail:t1'), findsOneWidget);
      expect(find.text('review:t1'), findsNothing);
    });

    testWidgets('an unregistered trailing segment falls through to detail', (
      tester,
    ) async {
      routes.value = _route(
        '$templatesUrl/t1/unknown',
        pathParameters: const {'templateId': 't1'},
      );
      await pump(tester, detailSubRoutes: reviewRoute());

      expect(find.text('detail:t1'), findsOneWidget);
    });

    testWidgets('a bare detail URL is not matched against the sub-route map, '
        'even when the id itself spells a registered segment', (tester) async {
      routes.value = _route(
        '$templatesUrl/review',
        pathParameters: const {'templateId': 'review'},
      );
      await pump(tester, detailSubRoutes: reviewRoute());

      expect(find.text('detail:review'), findsOneWidget);
      expect(find.text('review:review'), findsNothing);
    });

    testWidgets(
      'navigating detail → sub-route swaps the body: both share an id, so an '
      'id-only switcher key would leave the detail page on screen',
      (tester) async {
        routes.value = _route(
          '$templatesUrl/t1',
          pathParameters: const {'templateId': 't1'},
        );
        await pump(tester, detailSubRoutes: reviewRoute());
        expect(find.text('detail:t1'), findsOneWidget);

        routes.value = _route(
          '$templatesUrl/t1/review',
          pathParameters: const {'templateId': 't1'},
        );
        await tester.pumpAndSettle();

        expect(find.text('review:t1'), findsOneWidget);
        expect(find.text('detail:t1'), findsNothing);
      },
    );

    testWidgets('navigating sub-route → detail swaps back', (tester) async {
      routes.value = _route(
        '$templatesUrl/t1/review',
        pathParameters: const {'templateId': 't1'},
      );
      await pump(tester, detailSubRoutes: reviewRoute());
      expect(find.text('review:t1'), findsOneWidget);

      routes.value = _route(
        '$templatesUrl/t1',
        pathParameters: const {'templateId': 't1'},
      );
      await tester.pumpAndSettle();

      expect(find.text('detail:t1'), findsOneWidget);
      expect(find.text('review:t1'), findsNothing);
    });
  });
}
