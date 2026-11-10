import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:lotti/features/front_agent/model/front_entity_preview.dart';
import 'package:lotti/features/front_agent/model/front_reply_components.dart';
import 'package:lotti/features/front_agent/model/front_reply_layout.dart';
import 'package:lotti/features/front_agent/ui/front_entity_preview_card.dart';
import 'package:material_ui/material_ui.dart';

import 'front_reply_test_harness.dart';

void main() {
  const ice = FrontEntityReference(
    kind: FrontEntityKind.task,
    id: 't-ice',
    title: 'Check the ice-pad weather window',
  );
  const feed = FrontEntityReference(
    kind: FrontEntityKind.task,
    id: 't-feed',
    title: 'Feed the rescued chicks',
  );

  List<Map<String, Object?>> reply(
    String words,
    List<FrontEntityReference> cards,
  ) => frontReplyComponents(
    parts: [FrontReplyText(words), FrontReplyCards(cards)],
  );

  testWidgets('draws its components on a GenUI surface named for the reply', (
    tester,
  ) async {
    await pumpReplySurface(
      tester,
      reply('One is due:', [ice]),
      taps: FrontReplyTaps(),
      surfaceId: 'reply-7',
    );

    final surface = tester.widget<Surface>(find.byType(Surface));
    expect(surface.surfaceContext.surfaceId, 'reply-7');
    expect(find.text('words: One is due:'), findsOneWidget);
    expect(find.byKey(FrontEntityPreviewKeys.card('t-ice')), findsOneWidget);
  });

  testWidgets('a reply whose components change is updated on the same '
      'surface, not drawn anew', (tester) async {
    final taps = FrontReplyTaps();
    await pumpReplySurface(tester, reply('One is due:', [ice]), taps: taps);
    final before = tester.state(find.byType(Surface));

    await pumpReplySurface(
      tester,
      reply('Two are due:', [ice, feed]),
      taps: taps,
    );

    expect(tester.state(find.byType(Surface)), same(before));
    expect(find.text('words: One is due:'), findsNothing);
    expect(find.text('words: Two are due:'), findsOneWidget);
    expect(
      tester
          .widget<FrontEntityPreviewList>(find.byType(FrontEntityPreviewList))
          .references,
      [ice, feed],
    );
  });

  testWidgets('leaving the chat disposes the surface cleanly', (tester) async {
    await pumpReplySurface(
      tester,
      reply('One is due:', [ice]),
      taps: FrontReplyTaps(),
    );

    await tester.pumpWidget(const SizedBox.shrink());

    expect(find.byType(Surface), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
