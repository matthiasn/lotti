import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/settings/settings_page_layout.dart';

import '../../test_helper.dart';

void main() {
  group('SettingsPageLayout.contentInsets', () {
    test('narrow panes use the header padding on both sides', () {
      final insets = SettingsPageLayout.contentInsets(375);
      expect(insets.start, 20);
      expect(insets.end, 20);
    });

    test('mid-width panes stay symmetric while content fits the cap', () {
      final insets = SettingsPageLayout.contentInsets(800);
      // Header padding at 720..991 is 56; 800 - 112 = 688 <= 840.
      expect(insets.start, 56);
      expect(insets.end, 56);
    });

    test('wide panes center the capped content column', () {
      final insets = SettingsPageLayout.contentInsets(1440);
      // Available span (1440 - 2*120) exceeds the cap, so the column
      // centers: equal insets of (1440 - 840) / 2.
      expect(insets.start, (1440 - SettingsPageLayout.maxContentWidth) / 2);
      expect(insets.end, insets.start);
      expect(
        1440 - insets.start - insets.end,
        SettingsPageLayout.maxContentWidth,
      );
    });
  });

  group('SettingsContentSliver', () {
    Future<void> pumpAt(
      WidgetTester tester, {
      required double width,
      required Key childKey,
    }) {
      // The bench renders inside the real test viewport, so widen the
      // view itself — a SizedBox alone would be clamped to the default
      // 800x600 surface and the responsive insets would resolve wrong.
      tester.view
        ..physicalSize = Size(width, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      return tester.pumpWidget(
        WidgetTestBench(
          mediaQueryData: MediaQueryData(size: Size(width, 800)),
          surfaceConstraints: BoxConstraints.tightFor(width: width),
          child: SizedBox(
            width: width,
            height: 600,
            child: CustomScrollView(
              slivers: [
                SettingsContentSliver(
                  sliver: SliverToBoxAdapter(
                    child: SizedBox(key: childKey, height: 10),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('applies the resolved insets to its sliver', (tester) async {
      const key = Key('content');
      await pumpAt(tester, width: 375, childKey: key);

      final rect = tester.getRect(find.byKey(key));
      expect(rect.left, 20);
      expect(rect.width, 375 - 40);
    });

    testWidgets('centers capped content on wide panes', (tester) async {
      const key = Key('content');
      await pumpAt(tester, width: 1440, childKey: key);

      final rect = tester.getRect(find.byKey(key));
      expect(rect.left, (1440 - SettingsPageLayout.maxContentWidth) / 2);
      expect(rect.width, SettingsPageLayout.maxContentWidth);
    });
  });
}
