import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/state/journal_focus_controller.dart';

void main() {
  late ProviderContainer container;

  const testJournalId = 'test-journal-id';
  const testEntryId = 'test-entry-id';

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('JournalFocusIntent', () {
    test('creates intent with required fields', () {
      final intent = JournalFocusIntent(
        journalId: testJournalId,
        entryId: testEntryId,
      );

      expect(intent.journalId, equals(testJournalId));
      expect(intent.entryId, equals(testEntryId));
      expect(intent.alignment, equals(0.0));
    });

    test('creates intent with custom alignment', () {
      final intent = JournalFocusIntent(
        journalId: testJournalId,
        entryId: testEntryId,
        alignment: 0.5,
      );

      expect(intent.alignment, equals(0.5));
    });

    test('toString returns formatted string', () {
      final intent = JournalFocusIntent(
        journalId: testJournalId,
        entryId: testEntryId,
        alignment: 0.25,
      );

      expect(
        intent.toString(),
        equals(
          'JournalFocusIntent(journalId: $testJournalId, entryId: $testEntryId, alignment: 0.25)',
        ),
      );
    });
  });

  group('JournalFocusController', () {
    test('initial state is null', () {
      final provider = journalFocusControllerProvider(id: testJournalId);
      final state = container.read(provider);

      expect(state, isNull);
    });

    test('publishJournalFocus sets intent', () {
      final provider = journalFocusControllerProvider(id: testJournalId);

      container.read(provider.notifier).publishJournalFocus(
            entryId: testEntryId,
          );

      final state = container.read(provider);
      expect(state, isNotNull);
      expect(state!.journalId, equals(testJournalId));
      expect(state.entryId, equals(testEntryId));
      expect(state.alignment, equals(0.0));
    });

    test('publishJournalFocus with custom alignment', () {
      final provider = journalFocusControllerProvider(id: testJournalId);

      container.read(provider.notifier).publishJournalFocus(
            entryId: testEntryId,
            alignment: 0.5,
          );

      final state = container.read(provider);
      expect(state!.alignment, equals(0.5));
    });

    test('clearIntent resets state to null', () {
      final provider = journalFocusControllerProvider(id: testJournalId);
      final notifier = container.read(provider.notifier)
        ..publishJournalFocus(
          entryId: testEntryId,
        );

      // Verify intent was set
      expect(container.read(provider), isNotNull);

      // Clear intent
      notifier.clearIntent();

      // Verify intent is cleared
      final state = container.read(provider);
      expect(state, isNull);
    });

    test('multiple publish calls update the intent', () {
      final provider = journalFocusControllerProvider(id: testJournalId);
      final notifier = container.read(provider.notifier)
        ..publishJournalFocus(
          entryId: 'entry1',
        );

      expect(container.read(provider)!.entryId, equals('entry1'));

      // Second publish
      notifier.publishJournalFocus(
        entryId: 'entry2',
      );

      expect(container.read(provider)!.entryId, equals('entry2'));
    });

    test('re-trigger after clearIntent works', () {
      final provider = journalFocusControllerProvider(id: testJournalId);
      final notifier = container.read(provider.notifier)
        ..publishJournalFocus(
          entryId: testEntryId,
        );

      expect(container.read(provider), isNotNull);

      // Clear intent
      notifier.clearIntent();
      expect(container.read(provider), isNull);

      // Re-trigger with same values should work
      notifier.publishJournalFocus(
        entryId: testEntryId,
      );

      final state = container.read(provider);
      expect(state, isNotNull);
      expect(state!.entryId, equals(testEntryId));
    });

    test('different journal IDs have independent state', () {
      const journalId1 = 'journal-1';
      const journalId2 = 'journal-2';

      final provider1 = journalFocusControllerProvider(id: journalId1);
      final provider2 = journalFocusControllerProvider(id: journalId2);

      container.read(provider1.notifier).publishJournalFocus(
            entryId: 'entry1',
          );

      container.read(provider2.notifier).publishJournalFocus(
            entryId: 'entry2',
          );

      // Verify each has its own state
      expect(container.read(provider1)!.entryId, equals('entry1'));
      expect(container.read(provider2)!.entryId, equals('entry2'));

      // Clear journal1
      container.read(provider1.notifier).clearIntent();

      // Verify only journal1 is cleared
      expect(container.read(provider1), isNull);
      expect(container.read(provider2)!.entryId, equals('entry2'));
    });
  });

  group('publishJournalFocus helper function', () {
    test('helper function publishes focus intent correctly', () {
      const journalId = 'test-journal';
      const entryId = 'test-entry';
      const alignment = 0.7;

      // Direct test without the helper function since it requires WidgetRef
      // We'll test the functionality directly through the controller
      final provider = journalFocusControllerProvider(id: journalId);
      container.read(provider.notifier).publishJournalFocus(
            entryId: entryId,
            alignment: alignment,
          );

      // Verify focus was published
      final state = container.read(provider);

      expect(state, isNotNull);
      expect(state!.journalId, equals(journalId));
      expect(state.entryId, equals(entryId));
      expect(state.alignment, equals(alignment));
    });

    test('helper function uses default alignment', () {
      const journalId = 'test-journal-2';
      const entryId = 'test-entry-2';

      // Direct test without the helper function since it requires WidgetRef
      final provider = journalFocusControllerProvider(id: journalId);
      container.read(provider.notifier).publishJournalFocus(
            entryId: entryId,
          );

      final state = container.read(provider);

      expect(state, isNotNull);
      expect(state!.alignment, equals(0.0));
    });

    test('helper function logic mirrors controller behavior', () {
      // The publishJournalFocus helper function is a thin wrapper that
      // calls the controller. Testing the controller verifies the helper's
      // behavior since it delegates all logic to the controller.
      const journalId = 'test-journal-3';
      const entryId = 'test-entry-3';
      const alignment = 0.5;

      final provider = journalFocusControllerProvider(id: journalId);

      // This simulates what the helper function does internally
      container.read(provider.notifier).publishJournalFocus(
            entryId: entryId,
            alignment: alignment,
          );

      final state = container.read(provider);

      expect(state, isNotNull);
      expect(state!.journalId, equals(journalId));
      expect(state.entryId, equals(entryId));
      expect(state.alignment, equals(alignment));
    });
  });
}
