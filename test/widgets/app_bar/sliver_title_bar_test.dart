import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/app_bar/sliver_title_bar.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';

import '../../widget_test_utils.dart';

Future<void> _pump(
  WidgetTester tester, {
  required String title,
  bool pinned = false,
  bool showBackButton = false,
  PreferredSizeWidget? bottom,
}) {
  return tester.pumpWidget(
    makeTestableWidget2(
      Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverTitleBar(
              title,
              pinned: pinned,
              showBackButton: showBackButton,
              bottom: bottom,
            ),
            SliverToBoxAdapter(child: Container(height: 2000)),
          ],
        ),
      ),
    ),
  );
}

void main() {
  group('SliverTitleBar', () {
    testWidgets('renders title with primary color in flexible space', (
      tester,
    ) async {
      await _pump(tester, title: 'Settings');

      expect(find.text('Settings'), findsOneWidget);

      final context = tester.element(find.byType(SliverTitleBar));
      final text = tester.widget<Text>(find.text('Settings'));
      expect(text.style?.color, Theme.of(context).primaryColor);
      expect(find.byType(FlexibleSpaceBar), findsOneWidget);
    });

    testWidgets('passes pinned through to SliverAppBar', (tester) async {
      for (final pinned in [false, true]) {
        await _pump(tester, title: 'Pinned check', pinned: pinned);

        final sliverAppBar = tester.widget<SliverAppBar>(
          find.byType(SliverAppBar),
        );
        expect(sliverAppBar.pinned, pinned);
      }
    });

    testWidgets('shows BackWidget only when showBackButton is true', (
      tester,
    ) async {
      await _pump(tester, title: 'No back');
      expect(find.byType(BackWidget), findsNothing);

      await _pump(tester, title: 'With back', showBackButton: true);
      expect(find.byType(BackWidget), findsOneWidget);

      // Let the BackWidget fadeIn animation (1s) finish so no timer is
      // pending when the test ends.
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('renders bottom widget when provided', (tester) async {
      await _pump(
        tester,
        title: 'With bottom',
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(30),
          child: Text('bottom content'),
        ),
      );

      expect(find.text('bottom content'), findsOneWidget);
    });
  });
}
