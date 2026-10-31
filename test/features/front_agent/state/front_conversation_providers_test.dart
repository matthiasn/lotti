import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_conversation.dart';
import 'package:lotti/features/front_agent/service/front_conversation_service.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/providers/agent_repository_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  FrontConversation conversation(
    String id, {
    bool archived = false,
    DateTime? at,
  }) => FrontConversation(
    id: id,
    title: id,
    lastActivity: at ?? DateTime(2026, 10, 31, 9),
    archived: archived,
  );

  /// Runs [body] on the fixture's day: "today" is a fixed date, never the
  /// machine's.
  Future<void> onTheDay(Future<void> Function() body) =>
      withClock(Clock.fixed(DateTime(2026, 10, 31, 12)), body);

  late MockFrontConversationService service;
  late StreamController<Set<String>> pings;
  late FrontConversationIndex index;

  setUp(() {
    service = MockFrontConversationService();
    pings = StreamController<Set<String>>.broadcast();
    addTearDown(pings.close);
    index = FrontConversationIndex.empty;
    when(service.load).thenAnswer((_) async => index);
  });

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        frontConversationServiceProvider.overrideWithValue(service),
        agentUpdateStreamProvider(
          frontAgentId,
        ).overrideWith((ref) => pings.stream),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(frontActiveConversationProvider, (_, _) {});
    addTearDown(sub.close);
    return c;
  }

  test('the service is wired from its leaves', () {
    final c = ProviderContainer(
      overrides: [
        agentRepositoryProvider.overrideWithValue(MockAgentRepository()),
        agentSyncServiceProvider.overrideWithValue(MockAgentSyncService()),
      ],
    );
    addTearDown(c.dispose);

    expect(
      c.read(frontConversationServiceProvider),
      isA<FrontConversationService>(),
    );
  });

  test(
    "resumes the newest conversation not archived while it is today's",
    () => onTheDay(() async {
      index = FrontConversationIndex(
        conversations: [
          conversation('c-3', archived: true),
          conversation('c-2'),
        ],
      );

      expect(
        await container().read(frontActiveConversationProvider.future),
        'c-2',
      );
    }),
  );

  test(
    'opens a fresh conversation when the newest one is from another day',
    () => onTheDay(() async {
      index = FrontConversationIndex(
        conversations: [
          conversation('c-2', at: DateTime(2026, 10, 30, 23, 59)),
        ],
      );

      final active = await container().read(
        frontActiveConversationProvider.future,
      );

      expect(active, isNot(anyOf('c-2', earlierConversationId)));
    }),
  );

  test('with nothing said yet, a fresh id that stays the same', () async {
    final c = container();

    final first = await c.read(frontActiveConversationProvider.future);
    c.invalidate(frontConversationsProvider);
    final again = await c.read(frontActiveConversationProvider.future);

    expect(first, isNot(earlierConversationId));
    expect(again, first);
  });

  test(
    'a picked conversation wins; a new one is a fresh id each time; a '
    'reset goes back to where the user left off',
    () => onTheDay(() async {
      index = FrontConversationIndex(conversations: [conversation('c-1')]);
      final c = container();
      final picker = c.read(frontPickedConversationProvider.notifier)
        ..picked = 'c-9';
      expect(await c.read(frontActiveConversationProvider.future), 'c-9');
      expect(picker.picked, 'c-9');

      picker.startNew();
      final fresh = await c.read(frontActiveConversationProvider.future);
      picker.startNew();
      final fresher = await c.read(frontActiveConversationProvider.future);
      expect({fresh, fresher, 'c-1', 'c-9'}, hasLength(4));

      picker.reset();
      expect(await c.read(frontActiveConversationProvider.future), 'c-1');
    }),
  );

  test(
    'a picked conversation deleted — on another device too — is left for '
    'where the user left off',
    () => onTheDay(() async {
      index = FrontConversationIndex(conversations: [conversation('c-1')]);
      final c = container();
      c.read(frontPickedConversationProvider.notifier).picked = 'c-9';
      expect(await c.read(frontActiveConversationProvider.future), 'c-9');

      // The deletion arrives through sync: the pick stays, but is not shown.
      index = FrontConversationIndex(
        conversations: [conversation('c-1')],
        deletedIds: const {'c-9'},
      );
      c.invalidate(frontConversationsProvider);
      expect(await c.read(frontActiveConversationProvider.future), 'c-1');
    }),
  );

  test(
    'a fresh id whose conversation was deleted is minted anew, so a send '
    'never lands in a deleted conversation',
    () => onTheDay(() async {
      final c = container();
      final fresh = await c.read(frontActiveConversationProvider.future);

      index = FrontConversationIndex(
        conversations: const [],
        deletedIds: {fresh},
      );
      c.invalidate(frontConversationsProvider);
      final next = await c.read(frontActiveConversationProvider.future);

      expect(next, isNot(fresh));
      expect(next, isNot(earlierConversationId));
      expect(c.read(frontFreshConversationIdProvider), next);
    }),
  );

  test('a pick made on an earlier day is not resumed', () async {
    index = FrontConversationIndex(conversations: [conversation('c-1')]);
    late ProviderContainer c;
    await withClock(Clock.fixed(DateTime(2026, 10, 30, 22)), () async {
      c = container();
      c.read(frontPickedConversationProvider.notifier).picked = 'c-9';
      expect(await c.read(frontActiveConversationProvider.future), 'c-9');
    });

    await onTheDay(() async {
      c.invalidate(frontActiveConversationProvider);
      expect(await c.read(frontActiveConversationProvider.future), 'c-1');
    });
  });

  test(
    "reloads on the front agent's update ping",
    () => onTheDay(() async {
      final reloaded = Completer<void>();
      var loads = 0;
      when(service.load).thenAnswer((_) async {
        if (++loads == 2) reloaded.complete();
        return index;
      });
      final c = container();
      await c.read(frontActiveConversationProvider.future);
      index = FrontConversationIndex(conversations: [conversation('c-1')]);

      pings.add({frontAgentId});
      await reloaded.future;

      expect(await c.read(frontActiveConversationProvider.future), 'c-1');
    }),
  );
}
