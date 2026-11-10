import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/front_agent/model/front_entity_preview.dart';
import 'package:lotti/features/front_agent/model/front_reply_layout.dart';

void main() {
  const ice = FrontEntityReference(
    kind: FrontEntityKind.task,
    id: 't-9',
    title: 'Check the ice-pad weather window',
  );
  const census = FrontEntityReference(
    kind: FrontEntityKind.project,
    id: 'p-1',
    title: 'Colony census',
  );

  test('every part round-trips through JSON, in order', () {
    const parts = [
      FrontReplyText('Two are due:'),
      FrontReplyCards([ice, census]),
      FrontReplyShow(FrontReplyAttachment.loggedTimeChart),
    ];

    expect(
      FrontReplyPart.listFromJson([for (final part in parts) part.toJson()]),
      parts,
    );
  });

  test('a part this build does not know reads as nothing, and a list skips '
      'it', () {
    for (final bad in <Object?>[
      null,
      'text',
      const <String, Object?>{},
      {'text': '   '},
      {'cards': <Object?>[]},
      {
        'cards': [
          {'kind': 'hologram', 'id': 'x', 'title': 'x'},
        ],
      },
      {'show': 'weather_map'},
    ]) {
      expect(FrontReplyPart.fromJson(bad), isNull, reason: '$bad');
    }
    expect(
      FrontReplyPart.listFromJson([
        {'show': 'weather_map'},
        {'text': 'Kept.'},
      ]),
      [const FrontReplyText('Kept.')],
    );
    expect(FrontReplyPart.listFromJson('nope'), isEmpty);
  });

  test('an attachment is read by its wire name only', () {
    for (final attachment in FrontReplyAttachment.values) {
      expect(
        FrontReplyAttachment.fromWireName(attachment.wireName),
        attachment,
      );
    }
    expect(FrontReplyAttachment.fromWireName('closedTasks'), isNull);
  });

  test('parts are equal, and hash alike, only with the same content', () {
    // Not const: a canonical constant would be the very same instance.
    // ignore: prefer_const_constructors
    final cards = FrontReplyCards(const [ice]);
    expect(cards, const FrontReplyCards([ice]));
    expect(cards.hashCode, const FrontReplyCards([ice]).hashCode);
    expect(cards, isNot(const FrontReplyCards([census])));
    expect(
      const FrontReplyText('a'),
      isNot(const FrontReplyShow(FrontReplyAttachment.closedTasks)),
    );
    // ignore: prefer_const_constructors
    final text = FrontReplyText('Two are due:');
    expect(text.hashCode, const FrontReplyText('Two are due:').hashCode);
    // ignore: prefer_const_constructors
    final show = FrontReplyShow(FrontReplyAttachment.closedTasks);
    expect(
      show.hashCode,
      const FrontReplyShow(FrontReplyAttachment.closedTasks).hashCode,
    );
    // A failing comparison names what differs.
    expect(text.toString(), 'FrontReplyText(Two are due:)');
    expect(cards.toString(), contains('FrontReplyCards([FrontEntityReference'));
    expect(show.toString(), 'FrontReplyShow(closed_tasks)');
  });
}
