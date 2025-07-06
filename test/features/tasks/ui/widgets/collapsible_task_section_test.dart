import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lotti/features/tasks/ui/widgets/collapsible_task_section.dart';
import 'package:lotti/themes/theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

void main() {
  group('CollapsibleTaskSection', () {
    Widget createTestWidget({
      required Widget child,
      ThemeMode themeMode = ThemeMode.light,
    }) {
      final lightTheme = withOverrides(
        FlexThemeData.light(
          scheme: FlexScheme.greyLaw,
          fontFamily: GoogleFonts.inclusiveSans().fontFamily,
        ),
      );
      final darkTheme = withOverrides(
        FlexThemeData.dark(
          scheme: FlexScheme.greyLaw,
          fontFamily: GoogleFonts.inclusiveSans().fontFamily,
        ),
      );

      return MaterialApp(
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: themeMode,
        home: Scaffold(
          body: child,
        ),
      );
    }

    testWidgets('displays title and icon correctly', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: CollapsibleTaskSection(
            title: 'Test Section',
            icon: MdiIcons.checkCircle,
            expandedChild: const Text('Expanded content'),
            collapsedChild: const Text('Collapsed content'),
          ),
        ),
      );

      // Allow animations to complete
      await tester.pumpAndSettle();

      expect(find.text('Test Section'), findsOneWidget);
      expect(find.byIcon(MdiIcons.checkCircle), findsOneWidget);
    });

    testWidgets('shows expanded content when initially expanded',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const CollapsibleTaskSection(
            title: 'Test Section',
            expandedChild: Text('Expanded content'),
            collapsedChild: Text('Collapsed content'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Expanded content'), findsOneWidget);
      expect(find.text('Collapsed content'), findsNothing);
    });

    testWidgets('shows collapsed content when initially collapsed',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const CollapsibleTaskSection(
            title: 'Test Section',
            initiallyExpanded: false,
            expandedChild: Text('Expanded content'),
            collapsedChild: Text('Collapsed content'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Expanded content'), findsNothing);
      expect(find.text('Collapsed content'), findsOneWidget);
    });

    testWidgets('toggles expansion when tapped', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const CollapsibleTaskSection(
            title: 'Test Section',
            expandedChild: Text('Expanded content'),
            collapsedChild: Text('Collapsed content'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Expanded content'), findsOneWidget);

      // Tap to collapse
      await tester.tap(find.text('Test Section'));
      await tester.pumpAndSettle();

      expect(find.text('Expanded content'), findsNothing);
      expect(find.text('Collapsed content'), findsOneWidget);

      // Tap to expand again
      await tester.tap(find.text('Test Section'));
      await tester.pumpAndSettle();

      expect(find.text('Expanded content'), findsOneWidget);
      expect(find.text('Collapsed content'), findsNothing);
    });

    testWidgets('calls onExpansionChanged callback', (tester) async {
      bool? expansionState;

      await tester.pumpWidget(
        createTestWidget(
          child: CollapsibleTaskSection(
            title: 'Test Section',
            expandedChild: const Text('Expanded content'),
            collapsedChild: const Text('Collapsed content'),
            onExpansionChanged: (isExpanded) {
              expansionState = isExpanded;
            },
          ),
        ),
      );

      await tester.tap(find.text('Test Section'));
      await tester.pumpAndSettle();

      expect(expansionState, false);

      await tester.tap(find.text('Test Section'));
      await tester.pumpAndSettle();

      expect(expansionState, true);
    });

    testWidgets('shows trailing widget when expanded', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const CollapsibleTaskSection(
            title: 'Test Section',
            expandedChild: Text('Expanded content'),
            collapsedChild: Text('Collapsed content'),
            trailing: Icon(Icons.edit),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.edit), findsOneWidget);

      // Collapse and verify trailing is hidden
      await tester.tap(find.text('Test Section'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit), findsNothing);
    });

    testWidgets('renders correctly in dark mode', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          themeMode: ThemeMode.dark,
          child: CollapsibleTaskSection(
            title: 'Test Section',
            icon: MdiIcons.checkCircle,
            expandedChild: const Text('Expanded content'),
            collapsedChild: const Text('Collapsed content'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify it renders without errors in dark mode
      expect(find.text('Test Section'), findsOneWidget);
      expect(find.byIcon(MdiIcons.checkCircle), findsOneWidget);
    });
  });
}
