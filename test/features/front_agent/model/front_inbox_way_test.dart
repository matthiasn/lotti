import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/front_agent/model/front_inbox_way.dart';

void main() {
  test('a way reads from its name, and nothing from another', () {
    for (final way in FrontInboxWay.values) {
      expect(FrontInboxWay.fromName(way.name), way);
    }
    expect(FrontInboxWay.fromName('note'), isNull);
    expect(FrontInboxWay.fromName(3), isNull);
    expect(FrontInboxWay.fromName(null), isNull);
  });

  test('a list keeps her order, each way once, without a name this build '
      'does not know', () {
    expect(
      FrontInboxWay.listFromJson(const [
        'event',
        'prompt',
        'hologram',
        'event',
        7,
      ]),
      [FrontInboxWay.event, FrontInboxWay.prompt],
    );
  });

  test('an empty list is none picked; no list is nothing said', () {
    expect(FrontInboxWay.listFromJson(const <Object?>[]), isEmpty);
    expect(FrontInboxWay.listFromJson(null), isNull);
    expect(FrontInboxWay.listFromJson('prompt'), isNull);
  });
}
