import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/whats_new/model/whats_new_content.dart';
import 'package:lotti/features/whats_new/model/whats_new_release.dart';
import 'package:lotti/features/whats_new/model/whats_new_state.dart';
import 'package:lotti/features/whats_new/state/whats_new_controller.dart';
import 'package:lotti/features/whats_new/ui/whats_new_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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

    testWidgets('Skip button closes modal', (tester) async {
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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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

      // Modal is showing
      expect(find.text('v0.9.980'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      // Tap Skip button
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      // Modal should be closed
      expect(find.text('v0.9.980'), findsNothing);
    });

    testWidgets('displays fallback banner when image URL is null',
        (tester) async {
      final contentWithoutBanner = WhatsNewContent(
        release: testRelease1,
        headerMarkdown: '# January Update',
        sections: ['## Feature 1'],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            whatsNewControllerProvider.overrideWith(
              () => _TestWhatsNewController(
                WhatsNewState(unseenContent: [contentWithoutBanner]),
              ),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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

      // Should show version badge (banner fallback should display)
      expect(find.text('v0.9.980'), findsOneWidget);

      // Should show auto_awesome icon (part of fallback)
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    });

    testWidgets('view past releases button works', (tester) async {
      var resetCalled = false;
      var showCalledCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            whatsNewControllerProvider.overrideWith(
              () => _ResettableWhatsNewController(
                onReset: () => resetCalled = true,
                onBuild: () => showCalledCount++,
              ),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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

      // Tap button to show modal (empty state)
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Should show empty state
      expect(find.text("You're all caught up!"), findsOneWidget);
      expect(find.text('View past releases'), findsOneWidget);

      // Tap view past releases
      await tester.tap(find.text('View past releases'));
      await tester.pumpAndSettle();

      // Reset should have been called
      expect(resetCalled, isTrue);
    });

    testWidgets('can navigate back to newer release', (tester) async {
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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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

      // Go to older release
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      expect(find.text('v0.9.970'), findsOneWidget);

      // Now left arrow should be visible
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);

      // Go back to newer release
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      expect(find.text('v0.9.980'), findsOneWidget);
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

/// Test controller that tracks reset calls and returns empty state.
class _ResettableWhatsNewController extends WhatsNewController {
  _ResettableWhatsNewController({
    this.onReset,
    this.onBuild,
  });

  final VoidCallback? onReset;
  final VoidCallback? onBuild;

  @override
  Future<WhatsNewState> build() async {
    onBuild?.call();
    return const WhatsNewState();
  }

  @override
  Future<void> resetSeenStatus() async {
    onReset?.call();
  }
}
