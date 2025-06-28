import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/modern_card_content.dart';

import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ModernCardContent Tests', () {
    testWidgets('title is rendered and styled correctly', (tester) async {
      const testTitle = 'Test Title';

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernCardContent(
            title: testTitle,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find title text
      expect(find.text(testTitle), findsOneWidget);

      // Check text style
      final text = tester.widget<Text>(find.text(testTitle));
      expect(text.style?.fontWeight, FontWeight.w700);
      expect(text.style?.fontSize, AppTheme.titleFontSize);
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets('title truncates with ellipsis when too long', (tester) async {
      const longTitle = 'This is a very long title that should be truncated '
          'with ellipsis when it exceeds the available space in the card';

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox(
            width: 200, // Constrain width to force truncation
            child: ModernCardContent(
              title: longTitle,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final text = tester.widget<Text>(find.text(longTitle));
      expect(text.overflow, TextOverflow.ellipsis);
      expect(text.maxLines, 1);
    });

    testWidgets('subtitle text is rendered when provided', (tester) async {
      const testTitle = 'Test Title';
      const testSubtitle = 'Test Subtitle';

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernCardContent(
            title: testTitle,
            subtitle: testSubtitle,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text(testTitle), findsOneWidget);
      expect(find.text(testSubtitle), findsOneWidget);

      // Check subtitle style
      final subtitleText = tester.widget<Text>(find.text(testSubtitle));
      expect(subtitleText.style?.fontSize, AppTheme.subtitleFontSize);
      expect(subtitleText.maxLines, 2);
    });

    testWidgets('subtitle widget is rendered instead of text', (tester) async {
      const testTitle = 'Test Title';
      const subtitleWidget = Row(
        children: [
          Icon(Icons.star, size: 16),
          Text('Custom Widget'),
        ],
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernCardContent(
            title: testTitle,
            subtitleWidget: subtitleWidget,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text(testTitle), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.text('Custom Widget'), findsOneWidget);
    });

    testWidgets('leading widget is positioned correctly', (tester) async {
      const testTitle = 'Test Title';
      const leadingIcon = Icon(Icons.folder);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernCardContent(
            title: testTitle,
            leading: leadingIcon,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Leading widget should be before title
      final row = tester.widget<Row>(find.byType(Row).first);
      expect(row.children.first, isA<Icon>());

      // Check spacing after leading widget
      expect(row.children[1], isA<SizedBox>());
      final spacer = row.children[1] as SizedBox;
      expect(spacer.width, AppTheme.spacingLarge);
    });

    testWidgets('trailing widget is positioned correctly', (tester) async {
      const testTitle = 'Test Title';
      const trailingIcon = Icon(Icons.arrow_forward);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernCardContent(
            title: testTitle,
            trailing: trailingIcon,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Trailing widget should be at the end
      final row = tester.widget<Row>(find.byType(Row).first);
      expect(row.children.last, isA<Icon>());

      // Check spacing before trailing widget
      expect(row.children[row.children.length - 2], isA<SizedBox>());
      final spacer = row.children[row.children.length - 2] as SizedBox;
      expect(spacer.width, AppTheme.spacingMedium);
    });

    testWidgets('compact mode adjusts spacing and text sizes', (tester) async {
      const testTitle = 'Test Title';
      const testSubtitle = 'Test Subtitle';

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernCardContent(
            title: testTitle,
            subtitle: testSubtitle,
            isCompact: true,
            leading: Icon(Icons.folder),
            trailing: Icon(Icons.arrow_forward),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check title font size
      final titleText = tester.widget<Text>(find.text(testTitle));
      expect(titleText.style?.fontSize, AppTheme.titleFontSizeCompact);

      // Check subtitle font size
      final subtitleText = tester.widget<Text>(find.text(testSubtitle));
      expect(subtitleText.style?.fontSize, AppTheme.subtitleFontSizeCompact);
      expect(subtitleText.maxLines, 1); // Compact mode uses 1 line

      // Check spacing
      final row = tester.widget<Row>(find.byType(Row).first);
      final leadingSpace = row.children[1] as SizedBox;
      expect(leadingSpace.width, AppTheme.spacingMedium);

      final trailingSpace = row.children[row.children.length - 2] as SizedBox;
      expect(trailingSpace.width, AppTheme.spacingSmall);
    });

    testWidgets('custom title style is applied', (tester) async {
      const testTitle = 'Test Title';
      const customStyle = TextStyle(
        fontSize: 30,
        color: Colors.red,
        fontStyle: FontStyle.italic,
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernCardContent(
            title: testTitle,
            titleStyle: customStyle,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final text = tester.widget<Text>(find.text(testTitle));
      expect(text.style?.fontSize, 30);
      expect(text.style?.color, Colors.red);
      expect(text.style?.fontStyle, FontStyle.italic);
    });

    testWidgets('custom subtitle style is applied', (tester) async {
      const testTitle = 'Test Title';
      const testSubtitle = 'Test Subtitle';
      const customStyle = TextStyle(
        fontSize: 20,
        color: Colors.blue,
        fontWeight: FontWeight.bold,
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernCardContent(
            title: testTitle,
            subtitle: testSubtitle,
            subtitleStyle: customStyle,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final text = tester.widget<Text>(find.text(testSubtitle));
      expect(text.style?.fontSize, 20);
      expect(text.style?.color, Colors.blue);
      expect(text.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('max lines for title works correctly', (tester) async {
      const testTitle = 'This is a very long title that spans multiple lines';

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernCardContent(
            title: testTitle,
            maxTitleLines: 3,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final text = tester.widget<Text>(find.text(testTitle));
      expect(text.maxLines, 3);
    });

    testWidgets('max lines for subtitle works correctly', (tester) async {
      const testTitle = 'Title';
      const testSubtitle = 'This is a very long subtitle that could span '
          'multiple lines depending on the available width';

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernCardContent(
            title: testTitle,
            subtitle: testSubtitle,
            maxSubtitleLines: 4,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final text = tester.widget<Text>(find.text(testSubtitle));
      expect(text.maxLines, 4);
    });

    testWidgets('empty subtitle is not rendered', (tester) async {
      const testTitle = 'Test Title';

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernCardContent(
            title: testTitle,
            subtitle: '',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text(testTitle), findsOneWidget);
      expect(find.text(''), findsNothing);

      // Check that there's no extra spacing
      final column = tester.widget<Column>(
        find.descendant(
          of: find.byType(Expanded),
          matching: find.byType(Column),
        ),
      );
      expect(column.children.length, 1); // Only title
    });

    testWidgets('subtitle widget takes precedence over subtitle text',
        (tester) async {
      const testTitle = 'Test Title';
      const testSubtitle = 'Text Subtitle';
      const widgetText = 'Widget Subtitle';

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernCardContent(
            title: testTitle,
            subtitle: testSubtitle,
            subtitleWidget: Text(widgetText),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text(widgetText), findsOneWidget);
      expect(find.text(testSubtitle), findsNothing);
    });

    testWidgets('content expands to fill available space', (tester) async {
      const testTitle = 'Test Title';

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ModernCardContent(
            title: testTitle,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(Expanded), findsOneWidget);
    });
  });
}
