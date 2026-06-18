import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_sync_modal.dart';
import 'package:lotti/features/sync/ui/provisioned_sync_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_helper.dart';
import '../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestGetItMocks mocks;
  late MockMatrixService mockMatrixService;
  late MockMatrixClient mockClient;
  late MockUserActivityService mockUserActivityService;

  setUp(() async {
    mocks = await setUpTestGetIt();
    mockMatrixService = MockMatrixService();
    mockClient = MockMatrixClient();
    mockUserActivityService = MockUserActivityService();
    when(mockMatrixService.isLoggedIn).thenReturn(false);
    when(() => mockMatrixService.syncRoomId).thenReturn(null);
    when(() => mockMatrixService.client).thenReturn(mockClient);
    when(() => mockClient.userID).thenReturn(null);
    when(() => mockUserActivityService.updateActivity()).thenReturn(null);
    // SliverBoxAdapterPage wires a scroll listener to UserActivityService.
    getIt.registerSingleton<UserActivityService>(mockUserActivityService);
  });

  tearDown(tearDownTestGetIt);

  Future<void> pump(WidgetTester tester, {required bool enabled}) async {
    when(
      () => mocks.journalDb.watchConfigFlag(enableMatrixFlag),
    ).thenAnswer((_) => Stream<bool>.value(enabled));
    await tester.pumpWidget(
      RiverpodWidgetTestBench(
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
        child: const ProvisionedSyncPage(),
      ),
    );
    await tester.pump();
    // Drain the page chrome's back-button fade-in so no timer is left
    // pending at teardown.
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets(
    'renders the provisioned-sync card when matrix sync is enabled',
    (tester) async {
      await pump(tester, enabled: true);

      final context = tester.element(find.byType(ProvisionedSyncPage));
      expect(find.byType(ProvisionedSyncSettingsCard), findsOneWidget);
      // Both the page header and the card surface the same title.
      expect(find.text(context.messages.provisionedSyncTitle), findsWidgets);
    },
  );

  testWidgets(
    'feature gate hides the card when matrix sync is disabled',
    (tester) async {
      await pump(tester, enabled: false);

      expect(find.byType(ProvisionedSyncSettingsCard), findsNothing);
    },
  );
}
