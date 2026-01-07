import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/whats_new/model/whats_new_content.dart';
import 'package:lotti/features/whats_new/model/whats_new_release.dart';
import 'package:lotti/features/whats_new/model/whats_new_state.dart';
import 'package:lotti/features/whats_new/state/whats_new_controller.dart';
import 'package:lotti/features/whats_new/ui/whats_new_indicator.dart';

void main() {
  final testRelease = WhatsNewRelease(
    version: '0.9.980',
    date: DateTime(2026, 1, 7),
    title: 'January Update',
    folder: '0.9.980',
  );

  final testContent = WhatsNewContent(
    release: testRelease,
    headerMarkdown: '# January Update',
    sections: ['## Feature 1'],
    bannerImageUrl: 'https://example.com/banner.jpg',
  );

  group('WhatsNewIndicator', () {
    testWidgets('shows indicator when hasUnseenRelease is true',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            whatsNewControllerProvider.overrideWith(
              () => _TestWhatsNewController(
                WhatsNewState(unseenContent: [testContent]),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: WhatsNewIndicator()),
          ),
        ),
      );

      // Use pump with duration to advance past async loading
      // Don't use pumpAndSettle due to infinite animation
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should find a Container with decoration (the indicator dot)
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Container && widget.decoration != null,
        ),
        findsOneWidget,
      );
    });

    testWidgets('hides indicator when hasUnseenRelease is false',
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
            home: Scaffold(body: WhatsNewIndicator()),
          ),
        ),
      );

      // Use pump with duration to advance past async loading
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should find SizedBox.shrink (empty) - exactly one SizedBox
      // that is the shrink variant
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      expect(
        sizedBoxes.any((box) => box.width == 0 || box.height == 0),
        isTrue,
      );
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
