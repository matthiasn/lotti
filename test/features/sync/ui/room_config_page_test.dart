import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/state/matrix_room_provider.dart';
import 'package:lotti/features/sync/ui/room_config_page.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../widget_test_utils.dart';

class MockMatrixService extends Mock implements MatrixService {}

class _FakeMatrixRoomController extends MatrixRoomController {
  _FakeMatrixRoomController({this.initialRoom});

  final String? initialRoom;
  bool leaveCalled = false;
  bool joinCalled = false;
  bool createCalled = false;
  String? joinedRoomId;

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
  Future<void> createRoom() async {
    createCalled = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMatrixService mockMatrixService;

  setUp(() {
    mockMatrixService = MockMatrixService();
    when(() => mockMatrixService.inviteRequests)
        .thenAnswer((_) => const Stream<SyncRoomInvite>.empty());
  });

  group('roomConfigPage sticky action bar', () {
    testWidgets('updates page index when navigating (no room configured)',
        (tester) async {
      // Start at page index 3 (room config page) with no room configured
      final pageIndexNotifier = ValueNotifier<int>(3);
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
            // No room configured - back should go to room discovery (page 2)
            matrixRoomControllerProvider
                .overrideWith(_FakeMatrixRoomController.new),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // When no room is configured, back goes to previous page (discovery)
      await tester.tap(find.text('Previous Page'));
      await tester.pumpAndSettle();
      expect(pageIndexNotifier.value, 2); // room discovery page

      // Reset to page 3
      pageIndexNotifier.value = 3;
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next Page'));
      await tester.pumpAndSettle();
      expect(pageIndexNotifier.value, 4); // unverified devices page
    });

    testWidgets('back button skips discovery when room is configured',
        (tester) async {
      // Start at page index 3 (room config page) with a room configured
      final pageIndexNotifier = ValueNotifier<int>(3);
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
            // Room IS configured - back should skip discovery
            matrixRoomControllerProvider.overrideWith(
              () => _FakeMatrixRoomController(initialRoom: '!room:server'),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // When room is configured, back skips discovery and goes to logged-in config
      await tester.tap(find.text('Previous Page'));
      await tester.pumpAndSettle();
      expect(pageIndexNotifier.value,
          1); // logged-in config page, skipped discovery
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
  });
}
