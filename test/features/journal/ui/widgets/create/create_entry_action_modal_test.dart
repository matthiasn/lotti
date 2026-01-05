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

class MockPersistenceLogic extends Mock implements PersistenceLogic {}

class MockJournalDb extends Mock implements JournalDb {}

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

    testWidgets('shows modal with all menu items when events enabled',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            journalDbProvider.overrideWithValue(mockDb),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => CreateEntryModal.show(
                    context: context,
                    linkedFromId: 'test-linked-id',
                    categoryId: 'test-category-id',
                  ),
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open the modal
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Verify the modal is displayed with menu items
      // Note: The exact number depends on platform (some items are conditional)
      // At minimum, we should have Event, Task, Audio, Timer, Text items
      expect(find.byType(CreateMenuListItem), findsWidgets);
    });

    testWidgets('shows dividers between menu items', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            journalDbProvider.overrideWithValue(mockDb),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => CreateEntryModal.show(
                    context: context,
                    linkedFromId: 'test-linked-id',
                    categoryId: 'test-category-id',
                  ),
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open the modal
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Verify dividers are present between items
      expect(find.byType(Divider), findsWidgets);
    });

    testWidgets('shows Timer item when linkedFromId is provided',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            journalDbProvider.overrideWithValue(mockDb),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => CreateEntryModal.show(
                    context: context,
                    linkedFromId: 'test-linked-id',
                    categoryId: 'test-category-id',
                  ),
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open the modal
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Verify Timer item is present (timer icon)
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    });

    testWidgets('hides Timer item when linkedFromId is null', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            journalDbProvider.overrideWithValue(mockDb),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => CreateEntryModal.show(
                    context: context,
                    linkedFromId: null,
                    categoryId: 'test-category-id',
                  ),
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open the modal
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Verify Timer item is NOT present
      expect(find.byIcon(Icons.timer_outlined), findsNothing);
    });

    testWidgets('hides Event item when enableEventsFlag is false',
        (tester) async {
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

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            journalDbProvider.overrideWithValue(mockDb),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => CreateEntryModal.show(
                    context: context,
                    linkedFromId: null,
                    categoryId: 'test-category-id',
                  ),
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open the modal
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Verify Event item is NOT present
      expect(find.byIcon(Icons.event_rounded), findsNothing);
    });

    testWidgets('displays correct icons for all standard menu items',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            journalDbProvider.overrideWithValue(mockDb),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => CreateEntryModal.show(
                    context: context,
                    linkedFromId: 'test-id',
                    categoryId: 'test-category',
                  ),
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open the modal
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Verify core icons are present
      expect(find.byIcon(Icons.event_rounded), findsOneWidget);
      expect(find.byIcon(Icons.task_alt_rounded), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
      expect(find.byIcon(Icons.notes_rounded), findsOneWidget);
    });
  });
}
