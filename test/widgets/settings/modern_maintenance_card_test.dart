import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/settings/modern_settings_cards.dart';

void main() {
  group('ModernMaintenanceCard Widget Tests', () {
    testWidgets('displays title and subtitle correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernMaintenanceCard(
              title: 'Test Title',
              subtitle: 'Test Description',
              icon: Icons.delete_rounded,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
      expect(find.text('Test Description'), findsOneWidget);
    });

    testWidgets('displays icon correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernMaintenanceCard(
              title: 'Test Title',
              subtitle: 'Test Description',
              icon: Icons.delete_rounded,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.delete_rounded), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernMaintenanceCard(
              title: 'Test Title',
              subtitle: 'Test Description',
              icon: Icons.delete_rounded,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ModernMaintenanceCard));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('shows destructive styling when isDestructive is true',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernMaintenanceCard(
              title: 'Destructive Action',
              subtitle: 'This will delete data',
              icon: Icons.delete_rounded,
              isDestructive: true,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Destructive Action'), findsOneWidget);
    });

    testWidgets('shows safe styling when isDestructive is false',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernMaintenanceCard(
              title: 'Safe Action',
              subtitle: 'This is safe to do',
              icon: Icons.sync_rounded,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Safe Action'), findsOneWidget);
    });

    testWidgets('displays without icon when icon is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernMaintenanceCard(
              title: 'Test Title',
              subtitle: 'Test Description',
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
      expect(find.text('Test Description'), findsOneWidget);
      // No specific icon should be found since icon is null
    });

    testWidgets('displays chevron icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernMaintenanceCard(
              title: 'Test Title',
              subtitle: 'Test Description',
              icon: Icons.delete_rounded,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('has proper card styling', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernMaintenanceCard(
              title: 'Test Title',
              subtitle: 'Test Description',
              icon: Icons.delete_rounded,
              onTap: () {},
            ),
          ),
        ),
      );

      // Check that it uses AnimatedContainer instead of Card
      expect(find.byType(AnimatedContainer), findsOneWidget);

      // Check that it has InkWell for proper touch feedback
      expect(find.byType(InkWell), findsOneWidget);
    });

    testWidgets('has proper margins', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernMaintenanceCard(
              title: 'Test Title',
              subtitle: 'Test Description',
              icon: Icons.delete_rounded,
              onTap: () {},
            ),
          ),
        ),
      );

      // Check that the InkWell contains a Container with proper padding
      expect(find.byType(InkWell), findsOneWidget);

      // Find the Container inside the InkWell
      final inkWell = tester.widget<InkWell>(find.byType(InkWell));
      expect(inkWell.child, isA<Container>());
    });

    testWidgets('supports compact mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernMaintenanceCard(
              title: 'Test Title',
              subtitle: 'Test Description',
              icon: Icons.delete_rounded,
              isCompact: true,
              onTap: () {},
            ),
          ),
        ),
      );

      // Test that the icon size is smaller in compact mode
      final icon = tester.widget<Icon>(find.byIcon(Icons.delete_rounded));
      expect(icon.size,
          AppTheme.iconSizeCompact); // Use constant instead of magic number
    });

    testWidgets('handles long text with ellipsis', (tester) async {
      const longTitle =
          'This is a very long title that should be truncated with ellipsis when it exceeds the available space';
      const longDescription =
          'This is a very long description that should also be truncated with ellipsis when it exceeds the available space in the card layout';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernMaintenanceCard(
              title: longTitle,
              subtitle: longDescription,
              icon: Icons.delete_rounded,
              onTap: () {},
            ),
          ),
        ),
      );

      // The text should be displayed but may be truncated
      expect(find.textContaining('This is a very long title'), findsOneWidget);
      expect(find.textContaining('This is a very long description'),
          findsOneWidget);
    });

    testWidgets('responds to tap gestures', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernMaintenanceCard(
              title: 'Test Title',
              subtitle: 'Test Description',
              icon: Icons.delete_rounded,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      // Tap the card
      await tester.tap(find.byType(ModernMaintenanceCard));
      await tester.pumpAndSettle();

      // Verify the callback was called
      expect(tapped, isTrue);
    });

    testWidgets('works with different icon types', (tester) async {
      final testIcons = [
        Icons.delete_rounded,
        Icons.sync_rounded,
        Icons.build_rounded,
        Icons.search_rounded,
        Icons.refresh_rounded,
      ];

      for (final icon in testIcons) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ModernMaintenanceCard(
                title: 'Test Title',
                subtitle: 'Test Description',
                icon: icon,
                onTap: () {},
              ),
            ),
          ),
        );

        expect(find.byIcon(icon), findsOneWidget);
      }
    });

    testWidgets('maintains consistent layout with different content lengths',
        (tester) async {
      final testCases = [
        {'title': 'Short', 'subtitle': 'Short desc'},
        {
          'title': 'Medium Length Title',
          'subtitle': 'Medium length description'
        },
        {
          'title': 'Very Long Title That Should Be Truncated',
          'subtitle':
              'Very long description that should also be truncated when it exceeds the available space'
        },
      ];

      for (final testCase in testCases) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ModernMaintenanceCard(
                title: testCase['title']!,
                subtitle: testCase['subtitle'],
                icon: Icons.delete_rounded,
                onTap: () {},
              ),
            ),
          ),
        );

        // Should always display the title and description
        expect(find.text(testCase['title']!), findsOneWidget);
        expect(find.text(testCase['subtitle']!), findsOneWidget);

        // Should always have the icon and chevron
        expect(find.byIcon(Icons.delete_rounded), findsOneWidget);
        expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      }
    });
  });
}
