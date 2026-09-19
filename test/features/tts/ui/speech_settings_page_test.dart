import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/tts/ui/speech_settings_body.dart';
import 'package:lotti/features/tts/ui/speech_settings_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';

import '../../../widget_test_utils.dart';

void main() {
  setUp(
    () => setUpTestGetIt(
      additionalSetup: () => getIt.registerSingleton<UserActivityService>(
        UserActivityService(),
      ),
    ),
  );
  tearDown(tearDownTestGetIt);

  testWidgets(
    'wraps the speech settings body in the titled page chrome with a back '
    'button',
    (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(const SpeechSettingsPage()),
      );
      await tester.pump();
      // Flush SliverBoxAdapterPage's 500ms fade-in so no timer is left
      // pending at teardown.
      await tester.pump(const Duration(milliseconds: 500));

      final page = tester.widget<SliverBoxAdapterPage>(
        find.byType(SliverBoxAdapterPage),
      );
      expect(page.title, 'Speech');
      expect(page.showBackButton, isTrue);
      expect(find.byType(SpeechSettingsBody), findsOneWidget);
      expect(find.text('Reading speed'), findsOneWidget);
    },
  );
}
