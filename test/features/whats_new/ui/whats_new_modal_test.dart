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
          child: const MaterialApp(
            home: Scaffold(body: WhatsNewModal()),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('No new updates'), findsOneWidget);
    });

    testWidgets('displays single release content when one unseen',
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
          child: const MaterialApp(
            home: Scaffold(body: WhatsNewModal()),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should have a PageView for releases
      expect(find.byType(PageView), findsOneWidget);

      // Should NOT show release indicator dots for single release
      expect(find.byType(AnimatedContainer), findsNothing);
    });

    testWidgets('displays multiple releases with navigation', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            whatsNewControllerProvider.overrideWith(
              () => _TestWhatsNewController(
                WhatsNewState(unseenContent: [testContent1, testContent2]),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: WhatsNewModal()),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should have indicator dots for 2 releases
      final animatedContainers = find.byType(AnimatedContainer);
      expect(animatedContainers, findsNWidgets(2));

      // Should show version number
      expect(find.text('v0.9.980'), findsOneWidget);
    });

    testWidgets('can swipe between releases', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            whatsNewControllerProvider.overrideWith(
              () => _TestWhatsNewController(
                WhatsNewState(unseenContent: [testContent1, testContent2]),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: WhatsNewModal()),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Initially showing first release
      expect(find.text('v0.9.980'), findsOneWidget);

      // Swipe left to go to older release
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      // Allow animation to complete
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // PageView should still exist after swiping
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('shows navigation arrows for multiple releases',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            whatsNewControllerProvider.overrideWith(
              () => _TestWhatsNewController(
                WhatsNewState(unseenContent: [testContent1, testContent2]),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: WhatsNewModal()),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show chevron right (to older) but not left (already at newest)
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
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
