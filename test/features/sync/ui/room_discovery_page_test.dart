import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/sync_room_discovery.dart';
import 'package:lotti/features/sync/state/matrix_room_provider.dart';
import 'package:lotti/features/sync/state/room_discovery_provider.dart';
import 'package:lotti/features/sync/ui/widgets/room_discovery_widget.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

class MockMatrixService extends Mock implements MatrixService {}

void main() {
  late MockMatrixService mockMatrixService;
  late ValueNotifier<int> pageIndexNotifier;

  setUp(() {
    mockMatrixService = MockMatrixService();
    pageIndexNotifier = ValueNotifier(0);
  });

  tearDown(() {
    pageIndexNotifier.dispose();
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        matrixServiceProvider.overrideWithValue(mockMatrixService),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              return SizedBox(
                height: 600,
                child: RoomDiscoveryWidget(
                  onRoomSelected: () {
                    ref.invalidate(matrixRoomControllerProvider);
                    pageIndexNotifier.value = pageIndexNotifier.value + 1;
                  },
                  onSkip: () {
                    ref.read(roomDiscoveryControllerProvider.notifier).reset();
                    pageIndexNotifier.value = pageIndexNotifier.value + 1;
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  group('roomDiscoveryPage', () {
    testWidgets('creates a valid modal page', (tester) async {
      when(() => mockMatrixService.discoverExistingSyncRooms())
          .thenAnswer((_) async => []);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should display the room discovery widget
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('advances page index when room is selected', (tester) async {
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
      when(() => mockMatrixService.getRoom())
          .thenAnswer((_) async => '!room:server');

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(pageIndexNotifier.value, equals(0));

      // Tap on the room card
      await tester.tap(find.text('Test Room'));
      await tester.pumpAndSettle();

      // Page index should have advanced
      expect(pageIndexNotifier.value, equals(1));
    });

    testWidgets('advances page index when skip is selected', (tester) async {
      when(() => mockMatrixService.discoverExistingSyncRooms())
          .thenAnswer((_) async => []);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(pageIndexNotifier.value, equals(0));

      // Tap on create new room button
      await tester.tap(find.text('Create New Room'));
      await tester.pumpAndSettle();

      // Page index should have advanced
      expect(pageIndexNotifier.value, equals(1));
    });

    testWidgets('shows loading state during discovery', (tester) async {
      final completer = Completer<List<SyncRoomCandidate>>();

      when(() => mockMatrixService.discoverExistingSyncRooms())
          .thenAnswer((_) => completer.future);

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the future to clean up
      completer.complete([]);
      await tester.pumpAndSettle();
    });
  });
}
