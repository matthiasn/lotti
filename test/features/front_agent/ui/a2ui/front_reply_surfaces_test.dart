import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/front_agent/model/front_entity_preview.dart';
import 'package:lotti/features/front_agent/model/front_reply_surface.dart';
import 'package:lotti/features/front_agent/ui/front_entity_preview_card.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import 'front_reply_test_harness.dart';

void main() {
  FrontEntityReference task(String id) =>
      FrontEntityReference(kind: FrontEntityKind.task, id: id, title: 'T $id');

  FrontReplySurface reply(
    String id,
    String words, [
    List<String> taskIds = const ['t-1'],
  ]) => FrontReplySurface.compose(
    surfaceId: id,
    components: [
      {'component': FrontReplyComponents.text, 'text': words},
      if (taskIds.isNotEmpty)
        {
          'component': FrontReplyComponents.taskCards,
          'items': [for (final taskId in taskIds) task(taskId).toJson()],
        },
    ],
  );

  List<String> listed(WidgetTester tester) => [
    for (final list in tester.widgetList<FrontEntityPreviewList>(
      find.byType(FrontEntityPreviewList),
    ))
      ...list.references.map((reference) => reference.id),
  ];

  testWidgets('every reply of the thread is a surface of one processor; a '
      'reply of words alone gets none', (tester) async {
    await pumpReplySurfaces(tester, {
      'a1': reply('a1', 'One:'),
      'a2': reply('a2', 'Just words.', const []),
      'a3': reply('a3', 'Two:', const ['t-2', 't-3']),
    }, taps: FrontReplyTaps());

    expect(find.byType(A2uiSurface), findsNWidgets(2));
    expect(find.text('words: One:'), findsOneWidget);
    expect(find.text('no surface: a2'), findsOneWidget);
    expect(listed(tester), ['t-1', 't-2', 't-3']);
  });

  testWidgets('a reply whose surface changes is updated in place: its '
      'surface and what it already shows stay mounted', (tester) async {
    final taps = FrontReplyTaps();
    // Her answer while she writes it: the cards, then words under them.
    FrontReplySurface writing(String? words) => FrontReplySurface.compose(
      surfaceId: 'a1',
      components: [
        {
          'component': FrontReplyComponents.taskCards,
          'items': [task('t-1').toJson()],
        },
        if (words != null)
          {'component': FrontReplyComponents.text, 'text': words},
      ],
    );
    await pumpReplySurfaces(tester, {'a1': writing(null)}, taps: taps);
    final surface = tester.widget<A2uiSurface>(find.byType(A2uiSurface));
    final cards = tester.element(find.byType(FrontEntityPreviewList));

    for (final words in ['Garden', 'Garden is the one.']) {
      await pumpReplySurfaces(tester, {'a1': writing(words)}, taps: taps);
      await tester.pump();

      expect(find.text('words: $words'), findsOneWidget);
      // Not recreated: the same surface, and the cards still mounted.
      expect(
        tester.widget<A2uiSurface>(find.byType(A2uiSurface)).surface,
        same(surface.surface),
      );
      expect(tester.element(find.byType(FrontEntityPreviewList)), same(cards));
      expect(listed(tester), ['t-1']);
    }
    expect(find.text('words: Garden'), findsNothing);
  });

  testWidgets('a reply that became words alone loses its surface, an '
      'unchanged one keeps its surface, and one that left is deleted', (
    tester,
  ) async {
    final taps = FrontReplyTaps();
    final kept = reply('a1', 'One:');
    await pumpReplySurfaces(tester, {
      'a1': kept,
      'a2': reply('a2', 'Old words:'),
      'a3': reply('a3', 'Going:'),
    }, taps: taps);
    final keptSurface = tester
        .widgetList<A2uiSurface>(find.byType(A2uiSurface))
        .first
        .surface;

    await pumpReplySurfaces(tester, {
      'a1': reply('a1', 'One:'),
      'a2': reply('a2', 'New words:', const ['t-9']),
    }, taps: taps);

    final surfaces = tester
        .widgetList<A2uiSurface>(find.byType(A2uiSurface))
        .toList();
    expect(surfaces, hasLength(2));
    expect(surfaces.first.surface, same(keptSurface));
    expect(find.text('words: Old words:'), findsNothing);
    expect(find.text('words: New words:'), findsOneWidget);
    expect(find.text('words: Going:'), findsNothing);
    expect(listed(tester), ['t-1', 't-9']);
  });

  testWidgets('a stored surface the processor refuses is logged without '
      'her words and left out, so the reply falls back', (tester) async {
    final logger = MockDomainLogger();
    await pumpReplySurfaces(
      tester,
      {
        'a1': const FrontReplySurface({
          'version': '1.0',
          'createSurface': {
            'surfaceId': 'a1',
            'catalogId': frontReplyCatalogId,
            'components': [
              {
                'id': 'root',
                'component': 'Reply',
                'children': ['c0'],
              },
              {'id': 'c0', 'component': 'TaskCards', 'note': 'secret words'},
            ],
          },
        }),
        'a2': reply('a2', 'Fine:'),
      },
      taps: FrontReplyTaps(),
      logger: logger,
    );

    expect(find.text('no surface: a1'), findsOneWidget);
    expect(find.text('words: Fine:'), findsOneWidget);
    final logged = verify(
      () => logger.error(
        LogDomain.agentWorkflow,
        captureAny(),
        stackTrace: any(named: 'stackTrace'),
        subDomain: 'FrontReplySurfaces',
        message: 'A reply surface could not be drawn',
        errorType: any(named: 'errorType'),
      ),
    ).captured.single;
    expect('$logged', isNot(contains('secret words')));
  });

  testWidgets('a quick reply of blank words, or another action, is not a '
      'turn', (tester) async {
    final taps = FrontReplyTaps();
    await pumpReplySurfaces(tester, {'a1': reply('a1', 'One:')}, taps: taps);
    final surface = tester
        .widget<A2uiSurface>(find.byType(A2uiSurface))
        .surface;

    await surface.dispatchAction({
      'name': 'quick_reply',
      'context': {'text': '   '},
    }, 'root');
    await surface.dispatchAction({'name': 'quick_reply'}, 'root');
    await surface.dispatchAction({
      'name': 'something_else',
      'context': {'text': 'Hello'},
    }, 'root');
    await surface.dispatchAction({
      'name': 'quick_reply',
      'context': {'text': ' Yes '},
    }, 'root');

    expect(taps.quickReplies, ['Yes']);
  });

  testWidgets('leaving the chat disposes the processor cleanly', (
    tester,
  ) async {
    await pumpReplySurfaces(tester, {
      'a1': reply('a1', 'One:'),
    }, taps: FrontReplyTaps());

    await tester.pumpWidget(const SizedBox.shrink());

    expect(find.byType(A2uiSurface), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
