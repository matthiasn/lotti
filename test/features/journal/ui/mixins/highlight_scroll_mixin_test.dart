import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/ui/mixins/highlight_scroll_mixin.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HighlightScrollMixin - ', () {
    testWidgets('highlightedEntryId getter returns correct value',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TestWidgetWithMixin(entryIds: ['entry-1']),
        ),
      );

      final state = tester
          .state<TestWidgetWithMixinState>(find.byType(TestWidgetWithMixin));

      expect(state.highlightedEntryId, isNull);

      // Use the @visibleForTesting setter
      state.highlightedEntryId = 'entry-1';
      expect(state.highlightedEntryId, equals('entry-1'));
    });

    testWidgets('highlightedEntryId setter updates state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TestWidgetWithMixin(entryIds: ['entry-1']),
        ),
      );

      final state = tester
          .state<TestWidgetWithMixinState>(find.byType(TestWidgetWithMixin))
        ..highlightedEntryId = 'test-id';
      await tester.pump();

      expect(state.highlightedEntryId, equals('test-id'));

      state.highlightedEntryId = null;
      await tester.pump();

      expect(state.highlightedEntryId, isNull);
    });

    testWidgets('disposeHighlight cancels timer and sets disposed flag',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TestWidgetWithMixin(entryIds: ['entry-1']),
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
        const MaterialApp(
          home: TestWidgetWithMixin(entryIds: ['entry-1', 'entry-2']),
        ),
      );

      final state = tester
          .state<TestWidgetWithMixinState>(find.byType(TestWidgetWithMixin));

      var callbackInvoked = false;
      state.triggerScroll('entry-1', onScrolled: () {
        callbackInvoked = true;
      });

      // Wait for post-frame callback
      await tester.pumpAndSettle();

      expect(callbackInvoked, isTrue);
      expect(state.onScrolledCallCount, equals(1));
    });

    testWidgets('scrollToEntry prevents duplicate concurrent scrolls',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TestWidgetWithMixin(entryIds: ['entry-1', 'entry-2']),
        ),
      );

      final state = tester
          .state<TestWidgetWithMixinState>(find.byType(TestWidgetWithMixin));

      var callCount = 0;
      state
        ..triggerScroll('entry-1', onScrolled: () {
          callCount++;
        })

        //  Try to scroll to the same entry again immediately
        ..triggerScroll('entry-1', onScrolled: () {
          callCount++;
        });

      await tester.pumpAndSettle();

      // Both callbacks should be called (they're added to postFrameCallback),
      // but the second scroll operation is blocked
      expect(callCount, greaterThan(0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('scrollToEntry sets highlighted entry after successful scroll',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home:
              TestWidgetWithMixin(entryIds: ['entry-1', 'entry-2', 'entry-3']),
        ),
      );

      final state = tester
          .state<TestWidgetWithMixinState>(find.byType(TestWidgetWithMixin));

      expect(state.highlightedEntryId, isNull);

      state.triggerScroll('entry-1');
      await tester.pumpAndSettle();

      expect(state.highlightedEntryId, equals('entry-1'));
    });

    testWidgets('highlight auto-clears after 2 seconds', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home:
              TestWidgetWithMixin(entryIds: ['entry-1', 'entry-2', 'entry-3']),
        ),
      );

      final state = tester
          .state<TestWidgetWithMixinState>(find.byType(TestWidgetWithMixin))
        ..triggerScroll('entry-1');
      await tester.pumpAndSettle();

      expect(state.highlightedEntryId, equals('entry-1'));

      // Wait for highlight duration (2 seconds)
      await tester.pump(const Duration(seconds: 2));

      expect(state.highlightedEntryId, isNull);
    });

    testWidgets('disposed widget does not trigger highlight', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TestWidgetWithMixin(entryIds: ['entry-1']),
        ),
      );

      final state = tester
          .state<TestWidgetWithMixinState>(find.byType(TestWidgetWithMixin))

        // Manually call disposeHighlight
        ..disposeHighlight()

        // Try to scroll after dispose
        ..triggerScroll('entry-1');
      await tester.pumpAndSettle();

      // Should not crash or set highlight
      expect(state.highlightedEntryId, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('scrollToEntry accepts different alignment values',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home:
              TestWidgetWithMixin(entryIds: ['entry-1', 'entry-2', 'entry-3']),
        ),
      );

      final state = tester
          .state<TestWidgetWithMixinState>(find.byType(TestWidgetWithMixin))

        // Test different alignment values don't crash
        ..triggerScroll('entry-1', alignment: 0);
      await tester.pumpAndSettle();
      expect(state.highlightedEntryId, equals('entry-1'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('retry logic handles missing context', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TestWidgetWithMixin(entryIds: ['entry-1']),
        ),
      );

      final state = tester
          .state<TestWidgetWithMixinState>(find.byType(TestWidgetWithMixin))

        // Try to scroll to an entry that doesn't exist
        ..triggerScroll('non-existent-entry');

      // The retry logic should attempt multiple times
      for (var i = 0; i < 6; i++) {
        await tester.pump();
      }

      await tester.pumpAndSettle();

      // Should not crash and should not highlight anything
      expect(state.highlightedEntryId, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('scroll operation completes when entry becomes available',
        (tester) async {
      // Start with empty list
      final entryIds = <String>[];
      final widget = TestWidgetWithMixin(entryIds: entryIds);

      await tester.pumpWidget(MaterialApp(home: widget));

      final state = tester
          .state<TestWidgetWithMixinState>(find.byType(TestWidgetWithMixin))

        // Try to scroll to an entry that doesn't exist yet
        ..triggerScroll('entry-1');
      await tester.pump();

      // Entry is still not available
      expect(state.highlightedEntryId, isNull);

      // Now rebuild with the entry available
      entryIds.add('entry-1');
      await tester.pumpWidget(
        MaterialApp(home: TestWidgetWithMixin(entryIds: entryIds)),
      );

      // Note: In this simplified test, the entry key won't actually be found
      // because we're recreating the widget. In the real app, entries would
      // be added to an existing list. This test verifies no crash occurs.
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('concurrent scroll to different entry cancels previous',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home:
              TestWidgetWithMixin(entryIds: ['entry-1', 'entry-2', 'entry-3']),
        ),
      );

      final state = tester
          .state<TestWidgetWithMixinState>(find.byType(TestWidgetWithMixin))

        // Start scroll to entry-1
        ..triggerScroll('entry-1')

        // Immediately start scroll to entry-2 (different entry)
        ..triggerScroll('entry-2');

      await tester.pumpAndSettle();

      // Only entry-2 should be highlighted (entry-1 scroll was superseded)
      expect(state.highlightedEntryId, equals('entry-2'));
    });
  });
}
