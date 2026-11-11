import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/front_agent/model/front_conversation.dart';
import 'package:lotti/features/front_agent/state/front_chat_category.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_mention_categories.dart';

import '../../categories/test_utils.dart';

void main() {
  // The penguin world's categories she may see.
  final penguins = CategoryTestUtils.createTestCategory(
    id: 'cat-penguins',
    name: 'Penguin Operations',
  );
  final habitat = CategoryTestUtils.createTestCategory(
    id: 'cat-habitat',
    name: 'Habitat Engineering',
  );

  FrontConversation conversation(String id, {Set<String> scope = const {}}) =>
      FrontConversation(
        id: id,
        title: id,
        lastActivity: DateTime(2026, 11, 11),
        archived: false,
        categoryIds: scope,
      );

  group('frontChatCategoryOf', () {
    final options = [penguins, habitat];

    test("with nothing picked, the conversation's newest scope", () {
      expect(
        frontChatCategoryOf(
          'c-1',
          pick: null,
          conversation: conversation('c-1', scope: {'cat-habitat'}),
          options: options,
        ),
        habitat,
      );
    });

    test('a pick made there wins over the stored scope', () {
      expect(
        frontChatCategoryOf(
          'c-1',
          pick: const FrontChatCategoryPick(
            conversationId: 'c-1',
            categoryId: 'cat-penguins',
          ),
          conversation: conversation('c-1', scope: {'cat-habitat'}),
          options: options,
        ),
        penguins,
      );
    });

    test('"Everything" picked there is none, whatever was stored', () {
      expect(
        frontChatCategoryOf(
          'c-1',
          pick: const FrontChatCategoryPick(
            conversationId: 'c-1',
            categoryId: null,
          ),
          conversation: conversation('c-1', scope: {'cat-habitat'}),
          options: options,
        ),
        isNull,
      );
    });

    test('a pick made in another conversation is not this one', () {
      expect(
        frontChatCategoryOf(
          'c-1',
          pick: const FrontChatCategoryPick(
            conversationId: 'c-2',
            categoryId: 'cat-penguins',
          ),
          conversation: conversation('c-1'),
          options: options,
        ),
        isNull,
      );
    });

    test('a conversation not begun, or in no category, is in none', () {
      for (final unscoped in [null, conversation('c-1')]) {
        expect(
          frontChatCategoryOf(
            'c-1',
            pick: null,
            conversation: unscoped,
            options: options,
          ),
          isNull,
        );
      }
    });

    test('a category she may no longer see reads as none', () {
      expect(
        frontChatCategoryOf(
          'c-1',
          pick: null,
          conversation: conversation('c-1', scope: {'cat-locked'}),
          options: options,
        ),
        isNull,
      );
    });
  });

  group('frontChatCategoryIdOf', () {
    test('is the pick made there, else the stored scope, unchecked', () {
      expect(
        frontChatCategoryIdOf(
          'c-1',
          pick: null,
          conversation: conversation('c-1', scope: {'cat-locked'}),
        ),
        'cat-locked',
      );
      expect(
        frontChatCategoryIdOf(
          'c-1',
          pick: const FrontChatCategoryPick(
            conversationId: 'c-1',
            categoryId: 'cat-penguins',
          ),
          conversation: conversation('c-1', scope: {'cat-locked'}),
        ),
        'cat-penguins',
      );
      expect(
        frontChatCategoryIdOf('c-1', pick: null, conversation: null),
        isNull,
      );
    });
  });

  group('frontChatCategoryPickProvider', () {
    test('starts with nothing picked, holds a pick, and resets', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final picker = container.read(frontChatCategoryPickProvider.notifier);
      expect(container.read(frontChatCategoryPickProvider), isNull);

      picker.pick('c-1', 'cat-penguins');
      final pick = container.read(frontChatCategoryPickProvider)!;
      expect(pick.conversationId, 'c-1');
      expect(pick.categoryId, 'cat-penguins');

      picker.reset();
      expect(container.read(frontChatCategoryPickProvider), isNull);
    });
  });

  group('frontChatCategoryProvider', () {
    ProviderContainer containerFor({
      FutureOr<String> Function()? active,
      Set<String> stored = const {},
    }) {
      final container = ProviderContainer(
        overrides: [
          frontMentionCategoriesProvider.overrideWithValue([
            penguins,
            habitat,
          ]),
          frontConversationsProvider.overrideWith(
            (ref) async => FrontConversationIndex(
              conversations: [conversation('c-1', scope: stored)],
            ),
          ),
          frontActiveConversationProvider.overrideWith(
            (ref) async => (active ?? () => 'c-1')(),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    Future<void> settle(ProviderContainer container) async {
      await container.read(frontConversationsProvider.future);
      await container.read(frontActiveConversationProvider.future);
    }

    test("is the open conversation's stored scope, then what is picked "
        'there, and follows a change of pick', () async {
      final container = containerFor(stored: {'cat-habitat'});
      final sub = container.listen(frontChatCategoryProvider, (_, _) {});
      addTearDown(sub.close);
      await settle(container);
      expect(sub.read(), habitat);

      container
          .read(frontChatCategoryPickProvider.notifier)
          .pick('c-1', 'cat-penguins');
      expect(sub.read(), penguins);
    });

    test('is none while no conversation is open yet', () async {
      final pending = Completer<String>();
      final container = containerFor(active: () => pending.future);
      final sub = container.listen(frontChatCategoryProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(frontConversationsProvider.future);

      expect(sub.read(), isNull);
      pending.complete('c-1');
    });

    test('keeps a pick for a chat not begun, which no index lists yet', () {
      return withClock(Clock.fixed(DateTime(2026, 11, 11)), () async {
        final container = containerFor(active: () => 'c-new');
        final sub = container.listen(frontChatCategoryProvider, (_, _) {});
        addTearDown(sub.close);
        await settle(container);
        expect(sub.read(), isNull);

        container
            .read(frontChatCategoryPickProvider.notifier)
            .pick('c-new', 'cat-habitat');
        expect(sub.read(), habitat);
      });
    });
  });
}
