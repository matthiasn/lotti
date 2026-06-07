import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/ui/mixins/highlight_scroll_mixin.dart';
import 'package:lotti/services/dev_logger.dart';

import '../../../../widget_test_utils.dart';

// Test widget that uses the mixin
class TestWidgetWithMixin extends StatefulWidget {
  const TestWidgetWithMixin({
    required this.entryIds,
    super.key,
  });

  final List<String> entryIds;

  @override
  State<TestWidgetWithMixin> createState() => TestWidgetWithMixinState();
}

class TestWidgetWithMixinState extends State<TestWidgetWithMixin>
    with HighlightScrollMixin {
  final Map<String, GlobalKey> _entryKeys = {};
  VoidCallback? onScrolledCallback;
  int onScrolledCallCount = 0;

  @override
  void initState() {
    super.initState();
    for (final id in widget.entryIds) {
      _entryKeys[id] = GlobalKey();
    }
  }

  @override
  void dispose() {
    disposeHighlight();
    super.dispose();
  }

  GlobalKey _getEntryKey(String entryId) {
    return _entryKeys.putIfAbsent(entryId, GlobalKey.new);
  }

  void triggerScroll(
    String entryId, {
    double alignment = 0.5,
    VoidCallback? onScrolled,
  }) {
    onScrolledCallback = onScrolled;
    scrollToEntry(
      entryId,
      alignment,
      getEntryKey: _getEntryKey,
      onScrolled: () {
        onScrolledCallCount++;
        onScrolled?.call();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        itemCount: widget.entryIds.length,
        itemBuilder: (context, index) {
          final id = widget.entryIds[index];
          return Container(
            key: _getEntryKey(id),
            height: 100,
            color: highlightedEntryId == id ? Colors.yellow : Colors.white,
            child: Text('Entry $id'),
          );
        },
      ),
    );
  }
}

/// A render object that throws while `Scrollable.ensureVisible` computes the
/// reveal offset (it reads `paintBounds` of the target). This deterministically
/// forces the `catch (e)` branch in `HighlightScrollMixin`'s scroll-with-retry
/// logic without leaking an uncaught framework exception: the throw happens
/// inside the awaited future returned by `ensureVisible`, so it is swallowed by
/// the mixin's own try/catch.
class _ThrowOnRevealBox extends SingleChildRenderObjectWidget {
  const _ThrowOnRevealBox({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderThrowOnReveal();
}

class _RenderThrowOnReveal extends RenderProxyBox {
  @override
  Rect get paintBounds => throw StateError('reveal-boom');
}

/// Host that wraps every entry in a [_ThrowOnRevealBox] so that scrolling to a
/// found, laid-out entry throws during reveal, exercising the catch branch.
class ThrowingScrollHost extends StatefulWidget {
  const ThrowingScrollHost({required this.entryIds, super.key});

  final List<String> entryIds;

  @override
  State<ThrowingScrollHost> createState() => ThrowingScrollHostState();
}

class ThrowingScrollHostState extends State<ThrowingScrollHost>
    with HighlightScrollMixin {
  final Map<String, GlobalKey> _entryKeys = {};
  int onScrolledCallCount = 0;

  @override
  void dispose() {
    disposeHighlight();
    super.dispose();
  }

  GlobalKey _getEntryKey(String entryId) =>
      _entryKeys.putIfAbsent(entryId, GlobalKey.new);

  void triggerScroll(String entryId, {VoidCallback? onScrolled}) {
    // isInitialLoad uses the (zero in test mode) initialScrollDelay so the
    // post-frame scroll attempt runs deterministically within a few pumps.
    scrollToEntry(
      entryId,
      0.5,
      getEntryKey: _getEntryKey,
      isInitialLoad: true,
      onScrolled: () {
        onScrolledCallCount++;
        onScrolled?.call();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          for (final id in widget.entryIds)
            _ThrowOnRevealBox(
              key: _getEntryKey(id),
              child: SizedBox(height: 100, child: Text('Entry $id')),
            ),
        ],
      ),
    );
  }
}

/// Host whose entry list grows on the live State (no recreation), so the
/// mixin's retry timer can find a key that appears after the first attempt.
class LateEntryHost extends StatefulWidget {
  const LateEntryHost({super.key});

  @override
  State<LateEntryHost> createState() => LateEntryHostState();
}

class LateEntryHostState extends State<LateEntryHost>
    with HighlightScrollMixin {
  final List<String> entryIds = [];
  final Map<String, GlobalKey> _entryKeys = {};

  @override
  void dispose() {
    disposeHighlight();
    super.dispose();
  }

  GlobalKey _getEntryKey(String entryId) =>
      _entryKeys.putIfAbsent(entryId, GlobalKey.new);

  void addEntry(String id) => setState(() => entryIds.add(id));

  void triggerScroll(String entryId, {VoidCallback? onScrolled}) {
    scrollToEntry(
      entryId,
      0.5,
      getEntryKey: _getEntryKey,
      onScrolled: onScrolled,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          for (final id in entryIds)
            Container(
              key: _getEntryKey(id),
              height: 100,
              color: highlightedEntryId == id ? Colors.yellow : Colors.white,
              child: Text('Entry $id'),
            ),
        ],
      ),
    );
  }
}

/// Harness with a short highlight window so the auto-clear test doesn't
/// need to pump 4.8 s of virtual time.
class ShortHighlightHost extends TestWidgetWithMixin {
  const ShortHighlightHost({required super.entryIds, super.key});

  @override
  State<TestWidgetWithMixin> createState() => ShortHighlightHostState();
}

class ShortHighlightHostState extends TestWidgetWithMixinState {
  @override
  Duration get highlightDuration => const Duration(milliseconds: 50);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    DevLogger.suppressOutput = true;
    DevLogger.clear();
  });

  tearDown(() {
    DevLogger.suppressOutput = false;
  });

  group('HighlightScrollMixin - ', () {
    testWidgets('highlightedEntryId getter returns correct value', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const TestWidgetWithMixin(entryIds: ['entry-1']),
        ),
      );

      final state = tester.state<TestWidgetWithMixinState>(
        find.byType(TestWidgetWithMixin),
      );

      expect(state.highlightedEntryId, isNull);

      // Use the @visibleForTesting setter
      state.highlightedEntryId = 'entry-1';
      expect(state.highlightedEntryId, equals('entry-1'));
    });

    testWidgets('highlightedEntryId setter updates state', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const TestWidgetWithMixin(entryIds: ['entry-1']),
        ),
      );

      final state = tester.state<TestWidgetWithMixinState>(
        find.byType(TestWidgetWithMixin),
      )..highlightedEntryId = 'test-id';
      await tester.pump();

      expect(state.highlightedEntryId, equals('test-id'));

      state.highlightedEntryId = null;
      await tester.pump();

      expect(state.highlightedEntryId, isNull);
    });

    testWidgets('disposeHighlight cancels timer and sets disposed flag', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const TestWidgetWithMixin(entryIds: ['entry-1']),
        ),
      );

      await tester.pump();

      // Dispose the widget
      await tester.pumpWidget(Container());

      // The disposeHighlight should have been called in dispose()
      // No assertion errors should occur
      expect(tester.takeException(), isNull);
    });

    testWidgets('scrollToEntry calls onScrolled callback', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const TestWidgetWithMixin(entryIds: ['entry-1', 'entry-2']),
        ),
      );

      final state = tester.state<TestWidgetWithMixinState>(
        find.byType(TestWidgetWithMixin),
      );

      var callbackInvoked = false;
      state.triggerScroll(
        'entry-1',
        onScrolled: () {
          callbackInvoked = true;
        },
      );

      // Wait for post-frame callback
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      expect(callbackInvoked, isTrue);
      expect(state.onScrolledCallCount, equals(1));
    });

    testWidgets('scrollToEntry prevents duplicate concurrent scrolls', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const TestWidgetWithMixin(entryIds: ['entry-1', 'entry-2']),
        ),
      );

      final state = tester.state<TestWidgetWithMixinState>(
        find.byType(TestWidgetWithMixin),
      );

      var callCount = 0;
      state
        ..triggerScroll(
          'entry-1',
          onScrolled: () {
            callCount++;
          },
        )
        //  Try to scroll to the same entry again immediately
        ..triggerScroll(
          'entry-1',
          onScrolled: () {
            callCount++;
          },
        );

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      // The dedup guard drops the second scroll entirely: only the first
      // onScrolled fires and the original entry ends up highlighted.
      expect(callCount, 1);
      expect(state.onScrolledCallCount, 1);
      expect(state.highlightedEntryId, 'entry-1');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'scrollToEntry sets highlighted entry after successful scroll',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            const TestWidgetWithMixin(
              entryIds: ['entry-1', 'entry-2', 'entry-3'],
            ),
          ),
        );

        final state = tester.state<TestWidgetWithMixinState>(
          find.byType(TestWidgetWithMixin),
        );

        expect(state.highlightedEntryId, isNull);

        state.triggerScroll('entry-1');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        expect(state.highlightedEntryId, equals('entry-1'));
      },
    );

    testWidgets('highlight auto-clears after highlight duration', (
      tester,
    ) async {
      // ShortHighlightHost overrides highlightDuration to 50 ms so the
      // auto-clear assertion doesn't pump 4.8 s of virtual time.
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const ShortHighlightHost(
            entryIds: ['entry-1', 'entry-2', 'entry-3'],
          ),
        ),
      );

      final state = tester.state<ShortHighlightHostState>(
        find.byType(ShortHighlightHost),
      )..triggerScroll('entry-1');
      // 100 ms scroll timer → post-frame; entry-1 is already visible so
      // ensureVisible resolves immediately and the highlight is set on the
      // following microtask pump.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      expect(state.highlightedEntryId, equals('entry-1'));

      // The overridden 50 ms window elapses → highlight clears.
      await tester.pump(const Duration(milliseconds: 60));

      expect(state.highlightedEntryId, isNull);
    });

    testWidgets('disposed widget does not trigger highlight', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const TestWidgetWithMixin(entryIds: ['entry-1']),
        ),
      );

      final state =
          tester.state<TestWidgetWithMixinState>(
              find.byType(TestWidgetWithMixin),
            )
            // Manually call disposeHighlight
            ..disposeHighlight()
            // Try to scroll after dispose
            ..triggerScroll('entry-1');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      // Should not crash or set highlight
      expect(state.highlightedEntryId, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('scrollToEntry accepts different alignment values', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const TestWidgetWithMixin(
            entryIds: ['entry-1', 'entry-2', 'entry-3'],
          ),
        ),
      );

      final state =
          tester.state<TestWidgetWithMixinState>(
              find.byType(TestWidgetWithMixin),
            )
            // Test different alignment values don't crash
            ..triggerScroll('entry-1', alignment: 0);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      expect(state.highlightedEntryId, equals('entry-1'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('retry logic handles missing context and logs warning', (
      tester,
    ) async {
      DevLogger.clear();

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const TestWidgetWithMixin(entryIds: ['entry-1']),
        ),
      );

      final state =
          tester.state<TestWidgetWithMixinState>(
              find.byType(TestWidgetWithMixin),
            )
            // Try to scroll to an entry that doesn't exist
            ..triggerScroll('non-existent-entry');

      // The mixin uses Timer-based retries. Under flutter_test
      // (FLUTTER_TEST=true) it runs maxScrollRetries=5 with
      // scrollRetryDelay=50ms, and each pump(60ms) drives exactly one
      // attempt (timer fire + scheduled frame), so 7 pumps leave
      // comfortable headroom past the 5 attempts.
      for (var i = 0; i < 7; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }

      // Drain remaining post-frame callbacks.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      // Should not crash and should not highlight anything
      expect(state.highlightedEntryId, isNull);
      expect(tester.takeException(), isNull);

      // Verify DevLogger.warning was called after max retries
      // The warning message format is:
      // 'Failed to scroll to entry $entryId after $maxScrollRetries attempts'
      final hasWarning = DevLogger.capturedLogs.any(
        (log) =>
            log.contains('HighlightScrollMixin') &&
            log.contains('Failed to scroll to entry'),
      );

      // Unconditional: the warning must be captured — a conditional
      // assertion could silently pass without verifying anything.
      expect(
        hasWarning,
        isTrue,
        reason:
            'Should log warning after max retries exceeded. '
            'Logs: ${DevLogger.capturedLogs}',
      );
    });

    testWidgets(
      'ensureVisible failure logs warning, clears intent, leaves no highlight',
      (tester) async {
        DevLogger.clear();

        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            const ThrowingScrollHost(entryIds: ['entry-1', 'entry-2']),
          ),
        );

        final state = tester.state<ThrowingScrollHostState>(
          find.byType(ThrowingScrollHost),
        );

        var callbackInvoked = false;
        state.triggerScroll(
          'entry-1',
          onScrolled: () => callbackInvoked = true,
        );

        // initialScrollDelay is zero in test mode; the post-frame callback runs
        // the throwing ensureVisible, then resolves the catch branch. Pump a few
        // frames so the timer fires, the post-frame callback runs, and the
        // awaited (throwing) future settles.
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 120));
        }

        // The catch branch treats the throw as terminal: it cancels the retry
        // timer (line 155) and clears the scroll intent exactly once (line 157),
        // so even after pumping well past the retry delay there is no second
        // attempt and the entry is never highlighted (highlight is only set on
        // the success path).
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 120));
        }

        expect(callbackInvoked, isTrue);
        expect(state.onScrolledCallCount, equals(1));
        expect(state.highlightedEntryId, isNull);
        expect(tester.takeException(), isNull);

        // The catch branch logs exactly one per-attempt failure message that
        // includes the thrown error (lines 150-152), and never reaches the
        // retries-exhausted message ('after N attempts').
        final catchLogs = DevLogger.capturedLogs
            .where(
              (log) =>
                  log.contains('HighlightScrollMixin') &&
                  log.contains('Failed to scroll to entry entry-1') &&
                  log.contains('reveal-boom'),
            )
            .toList();
        expect(
          catchLogs,
          hasLength(1),
          reason:
              'catch branch should log the failure with the thrown error once. '
              'Logs: ${DevLogger.capturedLogs}',
        );
        expect(
          DevLogger.capturedLogs.any((log) => log.contains('after')),
          isFalse,
          reason: 'should not reach the retries-exhausted path',
        );
      },
    );

    testWidgets(
      'retry finds an entry added after the first attempt and highlights it',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(const LateEntryHost()),
        );

        final state = tester.state<LateEntryHostState>(
          find.byType(LateEntryHost),
        );

        var scrolled = false;
        state.triggerScroll('entry-late', onScrolled: () => scrolled = true);

        // First attempt: the entry is not in the list yet → retry scheduled.
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();
        expect(state.highlightedEntryId, isNull);
        expect(scrolled, isFalse);

        // Add the entry to the SAME state (no widget recreation), as the
        // real list does when new entries stream in.
        state.addEntry('entry-late');
        await tester.pump();

        // The next retry tick (50 ms in test mode) finds the key and the
        // scroll succeeds: intent cleared, highlight set.
        await tester.pump(const Duration(milliseconds: 60));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        expect(scrolled, isTrue);
        expect(state.highlightedEntryId, 'entry-late');
      },
    );

    testWidgets(
      'disposal between timer fire and post-frame hits the inner guard',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            const TestWidgetWithMixin(entryIds: ['entry-1']),
          ),
        );

        final state = tester.state<TestWidgetWithMixinState>(
          find.byType(TestWidgetWithMixin),
        )..triggerScroll('entry-1');

        // Registered BEFORE the mixin's own post-frame callback (which is
        // added when the 100 ms scroll timer fires inside the next pump),
        // so it runs first within the same frame — disposing right between
        // the outer `_disposed` check and the inner post-frame guard.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          state.disposeHighlight();
        });

        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        // The inner guard swallowed the scroll: no highlight, no crash.
        expect(state.highlightedEntryId, isNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('concurrent scroll to different entry cancels previous', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const TestWidgetWithMixin(
            entryIds: ['entry-1', 'entry-2', 'entry-3'],
          ),
        ),
      );

      final state =
          tester.state<TestWidgetWithMixinState>(
              find.byType(TestWidgetWithMixin),
            )
            // Start scroll to entry-1
            ..triggerScroll('entry-1')
            // Immediately start scroll to entry-2 (different entry)
            ..triggerScroll('entry-2');

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      // Only entry-2 should be highlighted (entry-1 scroll was superseded)
      expect(state.highlightedEntryId, equals('entry-2'));
    });

    test('shouldRetryScroll: exhaustive attempt × budget matrix', () {
      // Small finite space — exhaustive beats Glados. For any budget M,
      // attempts 0..M-2 retry and attempt M-1 (the last) gives up, so
      // exactly M-1 retries fire after the initial attempt.
      for (var max = 1; max <= 8; max++) {
        var retries = 0;
        for (var attempt = 0; attempt <= max; attempt++) {
          final retry = HighlightScrollMixin.shouldRetryScroll(
            attempt: attempt,
            maxRetries: max,
          );
          expect(
            retry,
            attempt < max - 1,
            reason: 'attempt=$attempt max=$max',
          );
          if (retry) retries++;
        }
        expect(retries, max - 1, reason: 'budget $max');
      }
    });
  });
}
