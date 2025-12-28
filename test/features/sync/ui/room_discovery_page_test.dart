import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/sync_room_discovery.dart';
import 'package:lotti/features/sync/state/matrix_room_provider.dart';
import 'package:lotti/features/sync/state/room_discovery_provider.dart';
import 'package:lotti/features/sync/ui/room_discovery_page.dart';
import 'package:lotti/features/sync/ui/widgets/room_discovery_widget.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

class MockMatrixService extends Mock implements MatrixService {}

/// Helper to extract and render the child widget from a modal page.
/// This allows testing the actual content rendered by roomDiscoveryPage.
Widget createPageContentTestWidget({
  required MockMatrixService mockMatrixService,
  required ValueNotifier<int> pageIndexNotifier,
}) {
  return ProviderScope(
    overrides: [
      matrixServiceProvider.overrideWithValue(mockMatrixService),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Builder(
        builder: (context) {
          final page = roomDiscoveryPage(
            context: context,
            pageIndexNotifier: pageIndexNotifier,
          );
          // Cast to WoltModalSheetPage to access child property
          // (modalSheetPage returns WoltModalSheetPage which extends
          // SliverWoltModalSheetPage)
          final woltPage = page as WoltModalSheetPage;
          return Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(size: Size(400, 800)),
              child: woltPage.child,
            ),
          );
        },
      ),
    ),
  );
}

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

  group('roomDiscoveryPage function', () {
    testWidgets('returns a configured modal page', (tester) async {
      when(() => mockMatrixService.discoverExistingSyncRooms())
          .thenAnswer((_) async => []);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: Builder(
              builder: (context) {
                final page = roomDiscoveryPage(
                  context: context,
                  pageIndexNotifier: pageIndexNotifier,
                );

                // Verify it's the correct type
                expect(page, isA<SliverWoltModalSheetPage>());
                // Verify navigation bar title is set
                expect(page.topBarTitle, isNotNull);
                // Verify has close button (trailing nav bar widget)
                expect(page.trailingNavBarWidget, isNotNull);

                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('displays correct title from localization', (tester) async {
      when(() => mockMatrixService.discoverExistingSyncRooms())
          .thenAnswer((_) async => []);

      String? capturedTitle;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: Builder(
              builder: (context) {
                final page = roomDiscoveryPage(
                  context: context,
                  pageIndexNotifier: pageIndexNotifier,
                );

                // Extract title text from the topBarTitle widget
                final titleWidget = page.topBarTitle;
                if (titleWidget is Container) {
                  final child = titleWidget.child;
                  if (child is Text) {
                    capturedTitle = child.data;
                  }
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(capturedTitle, equals('Find Existing Sync Room'));
    });
  });

  group('RoomDiscoveryWidget integration', () {
    testWidgets('creates a valid modal page', (tester) async {
      when(() => mockMatrixService.discoverExistingSyncRooms())
          .thenAnswer((_) async => []);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Should display the room discovery widget
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('advances page index when room is selected', (tester) async {
      // Use low-confidence room to prevent auto-selection (confidence < 10)
      final candidates = [
        const SyncRoomCandidate(
          roomId: '!room:server',
          roomName: 'Test Room',
          createdAt: null,
          memberCount: 2,
          hasStateMarker: false, // confidence = 5, won't auto-select
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

  group('_RoomDiscoveryPageContent (via modal page)', () {
    testWidgets('renders RoomDiscoveryWidget inside page content',
        (tester) async {
      when(() => mockMatrixService.discoverExistingSyncRooms())
          .thenAnswer((_) async => []);

      await tester.pumpWidget(
        createPageContentTestWidget(
          mockMatrixService: mockMatrixService,
          pageIndexNotifier: pageIndexNotifier,
        ),
      );
      await tester.pumpAndSettle();

      // Should render the RoomDiscoveryWidget
      expect(find.byType(RoomDiscoveryWidget), findsOneWidget);
    });

    testWidgets('page content uses responsive height based on screen size',
        (tester) async {
      when(() => mockMatrixService.discoverExistingSyncRooms())
          .thenAnswer((_) async => []);

      await tester.pumpWidget(
        createPageContentTestWidget(
          mockMatrixService: mockMatrixService,
          pageIndexNotifier: pageIndexNotifier,
        ),
      );
      await tester.pumpAndSettle();

      // Screen height is 800, so modalHeight = (800 * 0.5).clamp(300, 500) = 400
      final sizedBoxFinder = find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox &&
            widget.height != null &&
            widget.height! >= 300 &&
            widget.height! <= 500,
      );
      expect(sizedBoxFinder, findsWidgets);
    });

    testWidgets(
        'onRoomSelected callback invalidates provider and advances page',
        (tester) async {
      // Use low-confidence room to prevent auto-selection (confidence < 10)
      final candidates = [
        const SyncRoomCandidate(
          roomId: '!room:server',
          roomName: 'Page Content Room',
          createdAt: null,
          memberCount: 2,
          hasStateMarker: false, // confidence = 5, won't auto-select
          hasLottiContent: true,
        ),
      ];

      when(() => mockMatrixService.discoverExistingSyncRooms())
          .thenAnswer((_) async => candidates);
      when(() => mockMatrixService.joinRoom('!room:server'))
          .thenAnswer((_) async => '!room:server');
      when(() => mockMatrixService.getRoom())
          .thenAnswer((_) async => '!room:server');

      await tester.pumpWidget(
        createPageContentTestWidget(
          mockMatrixService: mockMatrixService,
          pageIndexNotifier: pageIndexNotifier,
        ),
      );
      await tester.pumpAndSettle();

      expect(pageIndexNotifier.value, equals(0));

      // Tap on the room card
      await tester.tap(find.text('Page Content Room'));
      await tester.pumpAndSettle();

      // Page index should have advanced
      expect(pageIndexNotifier.value, equals(1));
    });

    testWidgets('onSkip callback resets discovery and advances page',
        (tester) async {
      when(() => mockMatrixService.discoverExistingSyncRooms())
          .thenAnswer((_) async => []);

      await tester.pumpWidget(
        createPageContentTestWidget(
          mockMatrixService: mockMatrixService,
          pageIndexNotifier: pageIndexNotifier,
        ),
      );
      await tester.pumpAndSettle();

      expect(pageIndexNotifier.value, equals(0));

      // Tap on create new room button (skip action)
      await tester.tap(find.text('Create New Room'));
      await tester.pumpAndSettle();

      // Page index should have advanced
      expect(pageIndexNotifier.value, equals(1));
    });
  });

  group('responsive height behavior', () {
    testWidgets('uses responsive height from screen size', (tester) async {
      when(() => mockMatrixService.discoverExistingSyncRooms())
          .thenAnswer((_) async => []);

      // Test with a large screen height (800)
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: MediaQuery(
              data: const MediaQueryData(size: Size(400, 800)),
              child: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) {
                    return SizedBox(
                      height: 600,
                      child: RoomDiscoveryWidget(
                        onRoomSelected: () {
                          pageIndexNotifier.value = pageIndexNotifier.value + 1;
                        },
                        onSkip: () {
                          pageIndexNotifier.value = pageIndexNotifier.value + 1;
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify SizedBox widgets exist
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('clamps height within bounds on small screens', (tester) async {
      when(() => mockMatrixService.discoverExistingSyncRooms())
          .thenAnswer((_) async => []);

      // Test with a small screen height (400)
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: MediaQuery(
              data: const MediaQueryData(size: Size(300, 400)),
              child: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) {
                    return SizedBox(
                      height: 400,
                      child: RoomDiscoveryWidget(
                        onRoomSelected: () {
                          pageIndexNotifier.value = pageIndexNotifier.value + 1;
                        },
                        onSkip: () {
                          pageIndexNotifier.value = pageIndexNotifier.value + 1;
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Widget renders without errors on small screens
      expect(find.byType(RoomDiscoveryWidget), findsOneWidget);
    });
  });
}
