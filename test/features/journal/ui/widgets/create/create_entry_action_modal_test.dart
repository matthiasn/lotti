import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_entry_action_modal.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_menu_list_item.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  group('CreateEntryModal', () {
    late MockNavService mockNavService;
    late MockPersistenceLogic mockPersistenceLogic;
    late MockJournalDb mockDb;

    setUp(() {
      mockNavService = MockNavService();
      mockPersistenceLogic = MockPersistenceLogic();
      mockDb = MockJournalDb();

      // Mock watchConfigFlags to return enableEventsFlag: true
      when(() => mockDb.watchConfigFlags()).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          {
            const ConfigFlag(
              name: enableEventsFlag,
              description: 'Enable Events?',
              status: true,
            ),
          },
        ]),
      );

      getIt
        ..registerSingleton<NavService>(mockNavService)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<JournalDb>(mockDb);
    });

    tearDown(getIt.reset);

    /// Pumps a host button wired to CreateEntryModal.show and opens the
    /// modal (bottom-sheet route — the settle after the tap is required).
    Future<void> pumpAndOpenModal(
      WidgetTester tester, {
      String? linkedFromId = 'test-linked-id',
      String? categoryId = 'test-category-id',
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [journalDbProvider.overrideWithValue(mockDb)],
          child: makeTestableWidget2(
            Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => CreateEntryModal.show(
                    context: context,
                    linkedFromId: linkedFromId,
                    categoryId: categoryId,
                  ),
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows modal with all menu items when events enabled', (
      tester,
    ) async {
      await pumpAndOpenModal(tester);

      // "All" means all: with events enabled and a linked id, the five
      // core items must each be present exactly once (screenshot items are
      // platform-conditional and intentionally not pinned here).
      final context = tester.element(
        find.byType(CreateMenuListItem).first,
      );
      final messages = AppLocalizations.of(context)!;
      for (final label in [
        messages.addActionAddEvent,
        messages.addActionAddTask,
        messages.addActionAddAudioRecording,
        messages.addActionAddTimer,
        messages.addActionAddText,
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('shows dividers between menu items', (tester) async {
      await pumpAndOpenModal(tester);

      // Verify dividers are present between items
      expect(find.byType(Divider), findsWidgets);
    });

    testWidgets('shows Timer item when linkedFromId is provided', (
      tester,
    ) async {
      await pumpAndOpenModal(tester);

      // Verify Timer item is present (timer icon)
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    });

    testWidgets('hides Timer item when linkedFromId is null', (tester) async {
      await pumpAndOpenModal(tester, linkedFromId: null);

      // Verify Timer item is NOT present
      expect(find.byIcon(Icons.timer_outlined), findsNothing);
    });

    testWidgets('hides Event item when enableEventsFlag is false', (
      tester,
    ) async {
      // Override to disable events
      when(() => mockDb.watchConfigFlags()).thenAnswer(
        (_) => Stream<Set<ConfigFlag>>.fromIterable([
          {
            const ConfigFlag(
              name: enableEventsFlag,
              description: 'Enable Events?',
              status: false,
            ),
          },
        ]),
      );

      await pumpAndOpenModal(tester, linkedFromId: null);

      // Verify Event item is NOT present
      expect(find.byIcon(Icons.event_rounded), findsNothing);
    });

    testWidgets('displays correct icons for all standard menu items', (
      tester,
    ) async {
      await pumpAndOpenModal(
        tester,
        linkedFromId: 'test-id',
        categoryId: 'test-category',
      );

      // Verify core icons are present
      expect(find.byIcon(Icons.event_rounded), findsOneWidget);
      expect(find.byIcon(Icons.task_alt_rounded), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
      expect(find.byIcon(Icons.notes_rounded), findsOneWidget);
    });
  });
}
