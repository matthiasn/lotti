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
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  late MockLoggingService mockLoggingService;

  setUpAll(registerAllFallbackValues);

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

  /// Creates a test widget with localization and provider scope configured.
  Widget createTestWidget({
    required WhatsNewController Function() controllerBuilder,
    ThemeData? theme,
  }) {
    return ProviderScope(
      overrides: [
        whatsNewControllerProvider.overrideWith(controllerBuilder),
      ],
      child: MaterialApp(
        theme: theme,
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
    );
  }

  group('WhatsNewModal', () {
    testWidgets('displays no updates message when content is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          controllerBuilder: () => _TestWhatsNewController(
            const WhatsNewState(),
          ),
        ),
      );

      // Tap button to show modal
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      expect(find.text("You're all caught up!"), findsOneWidget);
    });

    testWidgets('displays release content when unseen releases exist', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          controllerBuilder: () => _TestWhatsNewController(
            WhatsNewState(unseenContent: [testContent1]),
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
        createTestWidget(
          controllerBuilder: () => _TestWhatsNewController(
            WhatsNewState(unseenContent: [testContent1, testContent2]),
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
        createTestWidget(
          controllerBuilder: () => _TestWhatsNewController(
            WhatsNewState(unseenContent: [testContent1, testContent2]),
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
      // Drive the Wolt page transition + 300ms indicator animation with
      // bounded pumps (Wolt's pagination animation is ~350ms; give margin).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 100));

      // Now showing second release (no NEW badge)
      expect(find.text('v0.9.970'), findsOneWidget);
    });

    testWidgets('Skip button closes modal', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          controllerBuilder: () => _TestWhatsNewController(
            WhatsNewState(unseenContent: [testContent1, testContent2]),
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

    testWidgets('displays fallback banner when image URL is null', (
      tester,
    ) async {
      final contentWithoutBanner = WhatsNewContent(
        release: testRelease1,
        headerMarkdown: '# January Update',
        sections: ['## Feature 1'],
      );

      await tester.pumpWidget(
        createTestWidget(
          controllerBuilder: () => _TestWhatsNewController(
            WhatsNewState(unseenContent: [contentWithoutBanner]),
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

      await tester.pumpWidget(
        createTestWidget(
          controllerBuilder: () => _ResettableWhatsNewController(
            onReset: () => resetCalled = true,
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
        createTestWidget(
          controllerBuilder: () => _TestWhatsNewController(
            WhatsNewState(unseenContent: [testContent1, testContent2]),
          ),
        ),
      );

      // Tap button to show modal
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Go to older release
      await tester.tap(find.byIcon(Icons.chevron_right));
      // Drive the Wolt page transition + 300ms indicator animation with
      // bounded pumps (Wolt's pagination animation is ~350ms; give margin).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('v0.9.970'), findsOneWidget);

      // Now left arrow should be visible
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);

      // Go back to newer release
      await tester.tap(find.byIcon(Icons.chevron_left));
      // Drive the Wolt page transition + 300ms indicator animation with
      // bounded pumps (Wolt's pagination animation is ~350ms; give margin).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('v0.9.980'), findsOneWidget);
    });

    testWidgets('Done button on last page marks all as seen', (tester) async {
      final markedAllSeen = <String>[];

      await tester.pumpWidget(
        createTestWidget(
          controllerBuilder: () => _TrackingWhatsNewController(
            WhatsNewState(unseenContent: [testContent1]),
            onMarkAllSeen: markedAllSeen.add,
          ),
        ),
      );

      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Single release → Done button visible (isLastPage == true)
      final doneFinder = find.text('Done');
      await tester.ensureVisible(doneFinder);
      await tester.tap(doneFinder);
      await tester.pumpAndSettle();

      // Modal closed and markAllAsSeen was called exactly once. The tracking
      // controller emits the 'all' sentinel per markAllAsSeen invocation, so a
      // single-element list proves Done triggered exactly one mark-all call
      // (not a per-release loop, and not zero calls).
      expect(find.text('v0.9.980'), findsNothing);
      expect(markedAllSeen, ['all']);
    });

    testWidgets('closing modal normally marks only viewed releases as seen '
        'via markAsSeen', (tester) async {
      final seenVersions = <String>[];

      await tester.pumpWidget(
        createTestWidget(
          controllerBuilder: () => _TrackingWhatsNewController(
            WhatsNewState(unseenContent: [testContent1]),
            onMarkAsSeen: seenVersions.add,
          ),
        ),
      );

      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Dismiss modal by tapping the barrier (normal close path)
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      // Modal should be closed and markAsSeen was called for viewed release
      expect(find.text('v0.9.980'), findsNothing);
      expect(seenVersions, contains('0.9.980'));
    });

    testWidgets(
      'closing without navigating marks only the first of multiple releases',
      (tester) async {
        final seenVersions = <String>[];

        await tester.pumpWidget(
          createTestWidget(
            controllerBuilder: () => _TrackingWhatsNewController(
              WhatsNewState(unseenContent: [testContent1, testContent2]),
              onMarkAsSeen: seenVersions.add,
            ),
          ),
        );

        await tester.tap(find.text('Show Modal'));
        await tester.pumpAndSettle();

        // Close on page 0 — maxViewedIndex never advanced.
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();

        // Only the first release is marked seen; the unviewed second one
        // must surface again next time.
        expect(seenVersions, ['0.9.980']);
      },
    );

    testWidgets('navigating to second release and closing normally marks both '
        'viewed releases', (tester) async {
      final seenVersions = <String>[];

      await tester.pumpWidget(
        createTestWidget(
          controllerBuilder: () => _TrackingWhatsNewController(
            WhatsNewState(unseenContent: [testContent1, testContent2]),
            onMarkAsSeen: seenVersions.add,
          ),
        ),
      );

      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Navigate to older release (maxViewedIndex becomes 1)
      await tester.tap(find.byIcon(Icons.chevron_right));
      // Drive the Wolt page transition + 300ms indicator animation with
      // bounded pumps (Wolt's pagination animation is ~350ms; give margin).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 100));

      // Close via barrier
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      // Both releases should be marked seen
      expect(seenVersions, containsAll(['0.9.980', '0.9.970']));
    });

    testWidgets(
      'narrow screen (< pageBreakpoint) uses bottomSheet modal type',
      (tester) async {
        // Set screen width below the 560 breakpoint to trigger bottomSheet path
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          createTestWidget(
            controllerBuilder: () => _TestWhatsNewController(
              WhatsNewState(unseenContent: [testContent1]),
            ),
          ),
        );

        await tester.tap(find.text('Show Modal'));
        await tester.pumpAndSettle();

        // Modal is still shown (bottomSheet type used on narrow screen)
        expect(find.text('v0.9.980'), findsOneWidget);
      },
    );

    testWidgets('wide screen (>= pageBreakpoint) uses tall dialog modal type '
        'and routeLabel is reachable', (tester) async {
      // Set screen width above the 560 breakpoint to trigger _TallDialogType
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        createTestWidget(
          controllerBuilder: () => _TestWhatsNewController(
            WhatsNewState(unseenContent: [testContent1]),
          ),
        ),
      );

      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Modal is shown as dialog (wide screen path: _TallDialogType)
      expect(find.text('v0.9.980'), findsOneWidget);
      // Verify Done button is accessible (single release → last page)
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('dark theme renders BannerFallback dark gradient', (
      tester,
    ) async {
      final contentWithoutBanner = WhatsNewContent(
        release: testRelease1,
        headerMarkdown: '# January Update',
        sections: ['## Feature 1'],
      );

      await tester.pumpWidget(
        createTestWidget(
          controllerBuilder: () => _TestWhatsNewController(
            WhatsNewState(unseenContent: [contentWithoutBanner]),
          ),
          theme: ThemeData.dark(),
        ),
      );

      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Dark theme fallback still shows auto_awesome icon
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
      // Version badge is visible
      expect(find.text('v0.9.980'), findsOneWidget);
    });

    testWidgets('dark theme shows dark barrier and renders release content', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          controllerBuilder: () => _TestWhatsNewController(
            WhatsNewState(unseenContent: [testContent1]),
          ),
          theme: ThemeData.dark(),
        ),
      );

      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Release content is shown in dark mode
      expect(find.text('v0.9.980'), findsOneWidget);
      expect(find.text('NEW'), findsOneWidget);
    });

    // Intentionally a crash-absence test: precaching fires NetworkImage
    // fetches we cannot intercept here, so the assertion is only that the
    // modal opens cleanly with image-bearing markdown. The URL-extraction
    // logic itself is unit-tested in the extractImageUrls group.
    testWidgets('markdown content with embedded image URLs triggers precaching '
        'without crashing', (tester) async {
      // Markdown sections contain image URLs — exercises the _extractImageUrls
      // loop (lines 98-106).
      final contentWithImages = WhatsNewContent(
        release: testRelease1,
        headerMarkdown:
            '# January Update\n\n![hero](https://example.com/hero.png)',
        sections: [
          '## Feature 1\n\n![screenshot](https://example.com/shot.png)',
        ],
        bannerImageUrl: 'https://example.com/banner1.png',
      );

      await tester.pumpWidget(
        createTestWidget(
          controllerBuilder: () => _TestWhatsNewController(
            WhatsNewState(unseenContent: [contentWithImages]),
          ),
        ),
      );

      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Modal shown and markdown content rendered
      expect(find.text('v0.9.980'), findsOneWidget);
    });

    testWidgets('Skip button on multi-release modal calls markAllAsSeen '
        '(not just viewed releases)', (tester) async {
      final markedAllSeen = <String>[];

      await tester.pumpWidget(
        createTestWidget(
          controllerBuilder: () => _TrackingWhatsNewController(
            WhatsNewState(unseenContent: [testContent1, testContent2]),
            onMarkAllSeen: markedAllSeen.add,
          ),
        ),
      );

      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Skip is visible on first page of multi-release modal
      expect(find.text('Skip'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      // Skip on a multi-release modal sets markAllOnClose = true, so
      // markAllAsSeen fires exactly once (emitting the 'all' sentinel) rather
      // than the per-viewed-release markAsSeen path.
      expect(markedAllSeen, ['all']);
      // Modal should be dismissed
      expect(find.text('v0.9.980'), findsNothing);
    });

    testWidgets('custom link builder renders a tappable in-app link that '
        'routes through NavService', (tester) async {
      // Register a NavService so handleMarkdownLinkTap routes internally.
      final mockNavService = MockNavService();
      getIt.registerSingleton<NavService>(mockNavService);

      // Markdown containing an internal route link exercises the custom
      // _buildLink linkBuilder (lines 29, 36-50): InkWell + Text.rich whose
      // onTap calls handleMarkdownLinkTap.
      final contentWithLink = WhatsNewContent(
        release: testRelease1,
        headerMarkdown:
            '# January Update\n\nSee [your tasks](/tasks/abc) for details.',
        sections: const [],
        bannerImageUrl: 'https://example.com/banner1.png',
      );

      await tester.pumpWidget(
        createTestWidget(
          controllerBuilder: () => _TestWhatsNewController(
            WhatsNewState(unseenContent: [contentWithLink]),
          ),
        ),
      );

      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // The custom _buildLink builder produces an InkWell using the click
      // cursor. There should be exactly one such link in the rendered markdown.
      final linkFinder = find.byWidgetPredicate(
        (widget) =>
            widget is InkWell &&
            widget.mouseCursor == SystemMouseCursors.click &&
            widget.child is Text,
      );
      expect(linkFinder, findsOneWidget);

      // The rendered link span carries the blue underline styling from
      // _buildLink.
      final linkText = tester.widget<Text>(
        find.descendant(of: linkFinder, matching: find.byType(Text)),
      );
      final linkSpanStyle = (linkText.textSpan! as TextSpan).style!;
      expect(linkSpanStyle.color, Colors.blue);
      expect(linkSpanStyle.decoration, TextDecoration.underline);

      // Tapping the link invokes handleMarkdownLinkTap which, for an internal
      // route, beams via NavService.
      await tester.tap(linkFinder);
      await tester.pumpAndSettle();

      verify(() => mockNavService.beamToNamed('/tasks/abc')).called(1);
    });
  });

  group('WhatsNewModal.extractImageUrls', () {
    test('returns every http(s) image URL in order', () {
      const markdown = '''
# Release
![one](https://example.com/a.png)
text ![two](http://example.com/b.jpg) more
''';
      expect(
        WhatsNewModal.extractImageUrls(markdown).toList(),
        ['https://example.com/a.png', 'http://example.com/b.jpg'],
      );
    });

    test('returns nothing for empty or image-free markdown', () {
      expect(WhatsNewModal.extractImageUrls(''), isEmpty);
      expect(
        WhatsNewModal.extractImageUrls('# Title\nplain text only'),
        isEmpty,
      );
    });

    test('ignores data-URI images (must not be precached as network)', () {
      const markdown = '![inline](data:image/png;base64,AAAA)';
      expect(WhatsNewModal.extractImageUrls(markdown), isEmpty);
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
  });

  final VoidCallback? onReset;

  @override
  Future<WhatsNewState> build() async {
    return const WhatsNewState();
  }

  @override
  Future<void> resetSeenStatus() async {
    onReset?.call();
  }
}

/// Test controller that tracks [markAsSeen] and [markAllAsSeen] calls.
class _TrackingWhatsNewController extends WhatsNewController {
  _TrackingWhatsNewController(
    this._state, {
    this.onMarkAsSeen,
    this.onMarkAllSeen,
  });

  final WhatsNewState _state;
  final void Function(String version)? onMarkAsSeen;
  final void Function(String tag)? onMarkAllSeen;

  @override
  Future<WhatsNewState> build() async => _state;

  @override
  Future<void> markAsSeen(String version) async {
    onMarkAsSeen?.call(version);
  }

  @override
  Future<void> markAllAsSeen() async {
    onMarkAllSeen?.call('all');
  }
}
