import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/sync_room_discovery.dart';
import 'package:lotti/features/sync/ui/widgets/room_discovery_widget.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

class MockMatrixService extends Mock implements MatrixService {}

void main() {
  late MockMatrixService mockMatrixService;

  setUp(() {
    mockMatrixService = MockMatrixService();
  });

  Widget createTestWidget({
    required VoidCallback onRoomSelected,
    required VoidCallback onSkip,
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        matrixServiceProvider.overrideWithValue(mockMatrixService),
        ...overrides,
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: RoomDiscoveryWidget(
              onRoomSelected: onRoomSelected,
              onSkip: onSkip,
            ),
          ),
        ),
      ),
    );
  }

  group('RoomDiscoveryWidget', () {
    testWidgets('shows loading indicator while discovering', (tester) async {
      // Use a completer to control when the future completes
      final completer = Completer<List<SyncRoomCandidate>>();

      when(() => mockMatrixService.discoverExistingSyncRooms())
          .thenAnswer((_) => completer.future);

      await tester.pumpWidget(createTestWidget(
        onRoomSelected: () {},
        onSkip: () {},
      ));

      // Wait for post-frame callback to trigger discovery
      await tester.pump();

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the future to clean up
      completer.complete([]);
      await tester.pumpAndSettle();
    });

    testWidgets('shows no rooms found message when empty', (tester) async {
      when(() => mockMatrixService.discoverExistingSyncRooms())
          .thenAnswer((_) async => []);

      await tester.pumpWidget(createTestWidget(
        onRoomSelected: () {},
        onSkip: () {},
      ));

      // Wait for discovery to complete
      await tester.pumpAndSettle();

      // Should show no rooms found message
      expect(find.byIcon(Icons.search_off), findsOneWidget);
      expect(find.text('Create New Room'), findsOneWidget);
    });

    testWidgets('shows room list when rooms are found', (tester) async {
      final candidates = [
        SyncRoomCandidate(
          roomId: '!room1:server',
          roomName: 'Sync Room 1',
          createdAt: DateTime(2024, 1, 15, 10, 30),
          memberCount: 2,
          hasStateMarker: true,
          hasLottiContent: true,
        ),
        const SyncRoomCandidate(
          roomId: '!room2:server',
          roomName: 'Sync Room 2',
          createdAt: null,
          memberCount: 3,
          hasStateMarker: false,
          hasLottiContent: true,
        ),
      ];

      when(() => mockMatrixService.discoverExistingSyncRooms())
          .thenAnswer((_) async => candidates);

      await tester.pumpWidget(createTestWidget(
        onRoomSelected: () {},
        onSkip: () {},
      ));

      await tester.pumpAndSettle();

      // Should show room cards
      expect(find.text('Sync Room 1'), findsOneWidget);
      expect(find.text('Sync Room 2'), findsOneWidget);
      expect(find.text('!room1:server'), findsOneWidget);
      expect(find.text('!room2:server'), findsOneWidget);

      // Should show indicators
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Has Content'), findsNWidgets(2));

      // Should show create new room button
      expect(find.text('Create New Room Instead'), findsOneWidget);
    });

    testWidgets('calls onSkip when create new room is tapped (no rooms)',
        (tester) async {
      var skipCalled = false;

      when(() => mockMatrixService.discoverExistingSyncRooms())
          .thenAnswer((_) async => []);

      await tester.pumpWidget(createTestWidget(
        onRoomSelected: () {},
        onSkip: () => skipCalled = true,
      ));

      await tester.pumpAndSettle();

      await tester.tap(find.text('Create New Room'));
      await tester.pumpAndSettle();

      expect(skipCalled, isTrue);
    });

    testWidgets('calls onSkip when create new room instead is tapped',
        (tester) async {
      var skipCalled = false;

      final candidates = [
        const SyncRoomCandidate(
          roomId: '!room:server',
          roomName: 'Test Room',
          createdAt: null,
          memberCount: 2,
          hasStateMarker: true,
          hasLottiContent: true,
        ),
      ];

      when(() => mockMatrixService.discoverExistingSyncRooms())
          .thenAnswer((_) async => candidates);

      await tester.pumpWidget(createTestWidget(
        onRoomSelected: () {},
        onSkip: () => skipCalled = true,
      ));

      await tester.pumpAndSettle();

      await tester.tap(find.text('Create New Room Instead'));
      await tester.pumpAndSettle();

      expect(skipCalled, isTrue);
    });

    testWidgets('joins room and calls onRoomSelected when room card is tapped',
        (tester) async {
      var roomSelected = false;

      final candidates = [
        const SyncRoomCandidate(
          roomId: '!room:server',
          roomName: 'Test Room',
          createdAt: null,
          memberCount: 2,
          hasStateMarker: true,
          hasLottiContent: true,
        ),
      ];

      when(() => mockMatrixService.discoverExistingSyncRooms())
          .thenAnswer((_) async => candidates);
      when(() => mockMatrixService.joinRoom('!room:server'))
          .thenAnswer((_) async => '!room:server');

      await tester.pumpWidget(createTestWidget(
        onRoomSelected: () => roomSelected = true,
        onSkip: () {},
      ));

      await tester.pumpAndSettle();

      // Tap on the room card
      await tester.tap(find.text('Test Room'));
      await tester.pumpAndSettle();

      expect(roomSelected, isTrue);
      verify(() => mockMatrixService.joinRoom('!room:server')).called(1);
    });

    testWidgets('shows error state on discovery failure', (tester) async {
      when(() => mockMatrixService.discoverExistingSyncRooms())
          .thenThrow(Exception('Network error'));

      await tester.pumpWidget(createTestWidget(
        onRoomSelected: () {},
        onSkip: () {},
      ));

      await tester.pumpAndSettle();

      // Should show error message
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Failed to discover rooms'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('retry button triggers new discovery', (tester) async {
      var callCount = 0;

      when(() => mockMatrixService.discoverExistingSyncRooms()).thenAnswer(
        (_) {
          callCount++;
          if (callCount == 1) {
            throw Exception('First call fails');
          }
          return Future.value([]);
        },
      );

      await tester.pumpWidget(createTestWidget(
        onRoomSelected: () {},
        onSkip: () {},
      ));

      await tester.pumpAndSettle();

      // Should show error state
      expect(find.text('Retry'), findsOneWidget);

      // Tap retry
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // Should have called discover again and now show no rooms found
      expect(callCount, equals(2));
      expect(find.byIcon(Icons.search_off), findsOneWidget);
    });

    testWidgets('shows member count and confidence badge', (tester) async {
      final candidates = [
        const SyncRoomCandidate(
          roomId: '!room:server',
          roomName: 'High Confidence Room',
          createdAt: null,
          memberCount: 5,
          hasStateMarker: true,
          hasLottiContent: true,
        ),
      ];

      when(() => mockMatrixService.discoverExistingSyncRooms())
          .thenAnswer((_) async => candidates);

      await tester.pumpWidget(createTestWidget(
        onRoomSelected: () {},
        onSkip: () {},
      ));

      await tester.pumpAndSettle();

      // Should show member count
      expect(find.text('5'), findsOneWidget);

      // Should show confidence badge (10 + 5 = 15)
      expect(find.text('15'), findsOneWidget);
    });

    testWidgets('shows unnamed room label when room name is null',
        (tester) async {
      final candidates = [
        const SyncRoomCandidate(
          roomId: '!room:server',
          roomName: null,
          createdAt: null,
          memberCount: 2,
          hasStateMarker: true,
          hasLottiContent: false,
        ),
      ];

      when(() => mockMatrixService.discoverExistingSyncRooms())
          .thenAnswer((_) async => candidates);

      await tester.pumpWidget(createTestWidget(
        onRoomSelected: () {},
        onSkip: () {},
      ));

      await tester.pumpAndSettle();

      // Should show unnamed room label
      expect(find.text('Unnamed Room'), findsOneWidget);
    });
  });
}
