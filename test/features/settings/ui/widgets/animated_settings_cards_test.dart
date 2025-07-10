import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings/ui/widgets/animated_settings_cards.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('AnimatedModernSettingsCardWithIcon', () {
    testWidgets('renders title and icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const AnimatedModernSettingsCardWithIcon(
            title: 'Test Title',
            icon: Icons.settings,
          ),
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsWidgets);
    });

    testWidgets('renders subtitle when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const AnimatedModernSettingsCardWithIcon(
            title: 'Test Title',
            icon: Icons.settings,
            subtitle: 'Test Subtitle',
          ),
        ),
      );

      expect(find.text('Test Subtitle'), findsOneWidget);
    });

    testWidgets('renders trailing widget when provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const AnimatedModernSettingsCardWithIcon(
            title: 'Test Title',
            icon: Icons.settings,
            trailing: Text('Trailing'),
          ),
        ),
      );

      expect(find.text('Trailing'), findsOneWidget);
    });

    testWidgets('shows chevron by default', (WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const AnimatedModernSettingsCardWithIcon(
            title: 'Test Title',
            icon: Icons.settings,
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('hides chevron when showChevron is false',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const AnimatedModernSettingsCardWithIcon(
            title: 'Test Title',
            icon: Icons.settings,
            showChevron: false,
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });

    testWidgets('calls onTap when tapped', (WidgetTester tester) async {
      var tapped = false;
      await tester.pumpWidget(
        makeTestableWidget(
          AnimatedModernSettingsCardWithIcon(
            title: 'Test Title',
            icon: Icons.settings,
            onTap: () {
              tapped = true;
            },
          ),
        ),
      );

      await tester.tap(find.byType(AnimatedModernSettingsCardWithIcon));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('renders in compact mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const AnimatedModernSettingsCardWithIcon(
            title: 'Test Title',
            icon: Icons.settings,
            isCompact: true,
          ),
        ),
      );

      // Add assertions for compact mode if there are visual differences that can be tested
      // For example, checking sizes or padding. This can be complex.
      // For now, we just ensure it renders without error.
      expect(find.text('Test Title'), findsOneWidget);
    });
  });
}
