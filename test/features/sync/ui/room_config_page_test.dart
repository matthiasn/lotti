import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/state/matrix_room_provider.dart';
import 'package:lotti/features/sync/ui/room_config_page.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mocktail/mocktail.dart';

import '../../../widget_test_utils.dart';

// ignore_for_file: cascade_invocations

class MockMatrixService extends Mock implements MatrixService {}

class _FakeMatrixRoomController extends MatrixRoomController {
  _FakeMatrixRoomController({this.initialRoom});

  final String? initialRoom;
  bool leaveCalled = false;
  bool joinCalled = false;
  bool createCalled = false;
  String? joinedRoomId;
  bool inviteCalled = false;
  String? invitedUserId;

  @override
  Future<String?> build() async => initialRoom;

  @override
  Future<void> leaveRoom() async {
    leaveCalled = true;
  }

  @override
  Future<void> joinRoom(String roomId) async {
    joinCalled = true;
    joinedRoomId = roomId;
  }

  @override
  Future<void> inviteToRoom(String userId) async {
    inviteCalled = true;
    invitedUserId = userId;
  }

  @override
  Future<void> createRoom() async {
    createCalled = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(
      SyncRoomInvite(
        roomId: '!dummy:server',
        senderId: '@dummy:server',
        matchesExistingRoom: false,
      ),
    );
  });

  late MockMatrixService mockMatrixService;

  setUp(() {
    mockMatrixService = MockMatrixService();
    when(() => mockMatrixService.inviteRequests)
        .thenAnswer((_) => const Stream<SyncRoomInvite>.empty());
  });

  group('roomConfigPage sticky action bar', () {
    testWidgets('updates page index when navigating', (tester) async {
      final pageIndexNotifier = ValueNotifier<int>(1);
      addTearDown(pageIndexNotifier.dispose);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) {
              final page = roomConfigPage(
                context: context,
                pageIndexNotifier: pageIndexNotifier,
              );
              return page.stickyActionBar ?? const SizedBox.shrink();
            },
          ),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Previous Page'));
      await tester.pumpAndSettle();
      expect(pageIndexNotifier.value, 0);

      await tester.tap(find.text('Next Page'));
      await tester.pumpAndSettle();
      expect(pageIndexNotifier.value, 1);
    });
  });

  group('RoomConfig widget', () {
    testWidgets('renders existing room details and allows leaving',
        (tester) async {
      final controller = _FakeMatrixRoomController(initialRoom: '!room:server');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const RoomConfig(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            matrixRoomControllerProvider.overrideWith(() => controller),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.text('Leave room'), findsOneWidget);

      await tester.tap(find.text('Leave room'));
      await tester.pumpAndSettle();

      expect(controller.leaveCalled, isTrue);
    });

    testWidgets('allows joining and creating a room when none exists',
        (tester) async {
      final controller = _FakeMatrixRoomController();

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const RoomConfig(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            matrixRoomControllerProvider.overrideWith(() => controller),
          ],
        ),
      );

      await tester.pumpAndSettle();

      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);
      expect(find.byKey(const Key('matrix_join_room')), findsNothing);

      await tester.enterText(textFieldFinder, '!jointest:server');
      await tester.pumpAndSettle();

      final joinButtonFinder = find.byKey(const Key('matrix_join_room'));
      expect(joinButtonFinder, findsOneWidget);

      await tester.tap(joinButtonFinder);
      await tester.pumpAndSettle();

      expect(controller.joinCalled, isTrue);
      expect(controller.joinedRoomId, '!jointest:server');

      final createButtonFinder = find.byKey(const Key('matrix_create_room'));
      expect(createButtonFinder, findsOneWidget);

      await tester.tap(createButtonFinder);
      await tester.pumpAndSettle();

      expect(controller.createCalled, isTrue);
    });

    testWidgets('handleBarcode invites user and hides scanner state',
        (tester) async {
      final controller = _FakeMatrixRoomController(initialRoom: '!room:server');

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const RoomConfig(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            matrixRoomControllerProvider.overrideWith(() => controller),
          ],
        ),
      );

      await tester.pumpAndSettle();

      final element =
          tester.element(find.byType(RoomConfig)) as StatefulElement;
      final handle = element.state as RoomConfigStateAccess;
      handle.showCamForTesting = true;

      await handle.handleBarcodeForTesting(
        const BarcodeCapture(
          barcodes: [
            Barcode(rawValue: '@friend:server'),
          ],
        ),
      );

      await tester.pump();

      final inviteCalled = controller.inviteCalled;
      final invitedUserId = controller.invitedUserId;
      final showCamAfter = handle.showCamForTesting;
      expect(inviteCalled, isTrue);
      expect(invitedUserId, '@friend:server');
      expect(showCamAfter, isFalse);
    });

    testWidgets('invite stream shows dialog and accepts invite',
        (tester) async {
      final controller = StreamController<SyncRoomInvite>.broadcast();
      addTearDown(controller.close);
      when(() => mockMatrixService.inviteRequests)
          .thenAnswer((_) => controller.stream);
      when(() => mockMatrixService.acceptInvite(any()))
          .thenAnswer((_) async {});

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const RoomConfig(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
            matrixRoomControllerProvider.overrideWith(
              () => _FakeMatrixRoomController(initialRoom: '!room:server'),
            ),
          ],
        ),
      );

      await tester.pump();

      controller.add(
        SyncRoomInvite(
          roomId: '!room:server',
          senderId: '@bob:server',
          matchesExistingRoom: true,
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();

      verify(() => mockMatrixService.acceptInvite(any())).called(1);
    });
  });
}
