import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/whats_new/model/whats_new_content.dart';
import 'package:lotti/features/whats_new/model/whats_new_release.dart';
import 'package:lotti/features/whats_new/model/whats_new_state.dart';
import 'package:lotti/features/whats_new/state/whats_new_controller.dart';
import 'package:lotti/features/whats_new/ui/whats_new_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLoggingService extends Mock implements LoggingService {}

void main() {
  late MockLoggingService mockLoggingService;

  setUp(() {
    mockLoggingService = MockLoggingService();
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    getIt.registerSingleton<LoggingService>(mockLoggingService);
  });

  tearDown(getIt.reset);

  final testRelease1 = WhatsNewRelease(
    version: '0.9.980',
    date: DateTime(2026, 1, 7),
    title: 'January Update',
    folder: '0.9.980',
  );

  final testRelease2 = WhatsNewRelease(
    version: '0.9.970',
    date: DateTime(2025, 12, 15),
    title: 'December Update',
    folder: '0.9.970',
  );

  final testContent1 = WhatsNewContent(
    release: testRelease1,
    headerMarkdown: '# January Update\n\nWelcome to the January update!',
    sections: ['## Feature 1\n\nNew feature description'],
    bannerImageUrl: 'https://example.com/banner1.png',
  );

  final testContent2 = WhatsNewContent(
    release: testRelease2,
    headerMarkdown: '# December Update\n\nDecember changes',
    sections: ['## Old Feature'],
    bannerImageUrl: 'https://example.com/banner2.png',
  );

  group('WhatsNewModal', () {
    testWidgets('displays no updates message when content is empty',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            whatsNewControllerProvider.overrideWith(
              () => _TestWhatsNewController(
                const WhatsNewState(),
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => ElevatedButton(
                  onPressed: () => WhatsNewModal.show(context, ref),
                  child: const Text('Show Modal'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap button to show modal
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      expect(find.text("You're all caught up!"), findsOneWidget);
    });

    testWidgets('displays release content when unseen releases exist',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            whatsNewControllerProvider.overrideWith(
              () => _TestWhatsNewController(
                WhatsNewState(unseenContent: [testContent1]),
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => ElevatedButton(
                  onPressed: () => WhatsNewModal.show(context, ref),
                  child: const Text('Show Modal'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap button to show modal
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Should show version badge
      expect(find.text('v0.9.980'), findsOneWidget);

      // Should show NEW indicator for latest release
      expect(find.text('NEW'), findsOneWidget);
    });

    testWidgets('displays navigation for multiple releases', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            whatsNewControllerProvider.overrideWith(
              () => _TestWhatsNewController(
                WhatsNewState(unseenContent: [testContent1, testContent2]),
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => ElevatedButton(
                  onPressed: () => WhatsNewModal.show(context, ref),
                  child: const Text('Show Modal'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap button to show modal
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Should show navigation arrow to older release
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      // Should show indicator dots for 2 releases
      final animatedContainers = find.byType(AnimatedContainer);
      expect(animatedContainers, findsNWidgets(2));
    });

    testWidgets('can navigate between releases', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            whatsNewControllerProvider.overrideWith(
              () => _TestWhatsNewController(
                WhatsNewState(unseenContent: [testContent1, testContent2]),
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => ElevatedButton(
                  onPressed: () => WhatsNewModal.show(context, ref),
                  child: const Text('Show Modal'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap button to show modal
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Initially showing first release with NEW badge
      expect(find.text('NEW'), findsOneWidget);
      expect(find.text('v0.9.980'), findsOneWidget);

      // Tap right arrow to go to older release
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      // Now showing second release (no NEW badge)
      expect(find.text('v0.9.970'), findsOneWidget);
    });
  });
}

/// Test controller that immediately returns the given state.
class _TestWhatsNewController extends WhatsNewController {
  _TestWhatsNewController(this._state);

  final WhatsNewState _state;

  @override
  Future<WhatsNewState> build() async => _state;
}
