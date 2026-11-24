import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/front_agent/model/front_conversation.dart';

void main() {
  group('frontCategoriesOf', () {
    test("reads a turn's chosen categories, ignoring what is not an id", () {
      expect(
        frontCategoriesOf({
          frontCategoriesKey: ['colony', 3, 'nests'],
        }),
        {'colony', 'nests'},
      );
      expect(frontCategoriesOf({frontCategoriesKey: 'colony'}), isEmpty);
      expect(frontCategoriesOf(const {}), isEmpty);
    });
  });

  group('frontNarrowedCategories', () {
    test('no chips leave her allow-list as it is', () {
      expect(frontNarrowedCategories({'work'}, const {}), {'work'});
      expect(frontNarrowedCategories(const {}, const {}), isEmpty);
    });

    test('chips narrow her allow-list to what both hold', () {
      expect(
        frontNarrowedCategories({'work', 'home'}, {'home', 'secret'}),
        {'home'},
      );
    });

    test('chips alone narrow an unrestricted allow-list', () {
      expect(frontNarrowedCategories(const {}, {'home'}), {'home'});
    });

    test('chips wholly outside her allow-list never widen it to the whole '
        'journal', () {
      expect(frontNarrowedCategories({'work'}, {'secret'}), {'work'});
    });
  });

  test('a conversation is in no category until a turn says so', () {
    final conversation = FrontConversation(
      id: 'c-1',
      title: 'Plan the census',
      lastActivity: DateTime(2026, 11, 11),
      archived: false,
    );
    expect(conversation.categoryIds, isEmpty);
    expect(
      FrontConversation(
        id: 'c-2',
        title: 'Fix the heat pump',
        lastActivity: DateTime(2026, 11, 11),
        archived: false,
        categoryIds: const {'cat-habitat'},
      ).categoryIds,
      {'cat-habitat'},
    );
  });

  test('only a reply marked stopped is the stop of its turn', () {
    expect(frontTurnStopped(const {frontTurnStoppedKey: true}), isTrue);
    expect(frontTurnStopped(const {'text': 'Forty-two.'}), isFalse);
    expect(frontTurnStopped(const {frontTurnStoppedKey: 'yes'}), isFalse);
    expect(frontTurnStopped(const {frontTurnStoppedKey: false}), isFalse);
  });

  test('a stop pressed twice, or on two devices, is one record', () {
    expect(frontChatStopMessageId('m-1'), frontChatStopMessageId('m-1'));
    expect(frontChatStopPayloadId('m-1'), frontChatStopPayloadId('m-1'));
    expect(frontChatStopMessageId('m-1'), isNot(frontChatStopMessageId('m-2')));
    expect(frontChatStopMessageId('m-1'), isNot(frontChatStopPayloadId('m-1')));
  });

  test('a turn names the stopped turn it replaces only by a non-empty id', () {
    expect(frontTurnReplaces(const {frontTurnReplacesKey: 'u1'}), 'u1');
    expect(frontTurnReplaces(const {'text': 'Count the eggs'}), isNull);
    expect(frontTurnReplaces(const {frontTurnReplacesKey: ''}), isNull);
    expect(frontTurnReplaces(const {frontTurnReplacesKey: 7}), isNull);
  });
}
