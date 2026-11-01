import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/front_agent/state/front_voice_providers.dart';

void main() {
  test("her voice in a conversation is that conversation's own", () {
    expect(frontVoiceSourceId('c-1'), 'front-chat:c-1');
    expect(frontVoiceSourceId('c-1'), isNot(frontVoiceSourceId('c-2')));
  });

  test('a spoken turn is marked with its conversation and moment, and '
      'settles', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final at = DateTime(2026, 10, 31, 9);

    expect(container.read(frontSpokenTurnProvider), isNull);
    withClock(Clock.fixed(at), () {
      container.read(frontSpokenTurnProvider.notifier).spoke('c-1');
    });
    expect(container.read(frontSpokenTurnProvider), (
      conversationId: 'c-1',
      spokenAt: at,
    ));

    container.read(frontSpokenTurnProvider.notifier).settle();
    expect(container.read(frontSpokenTurnProvider), isNull);
  });
}
