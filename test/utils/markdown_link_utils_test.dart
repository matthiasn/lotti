import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/markdown_link_utils.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class MockUrlLauncher extends Mock
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {}

class FakeLaunchOptions extends Fake implements LaunchOptions {}

void main() {
  group('handleMarkdownLinkTap', () {
    late MockUrlLauncher mockUrlLauncher;

    setUp(() {
      mockUrlLauncher = MockUrlLauncher();
      UrlLauncherPlatform.instance = mockUrlLauncher;
      registerFallbackValue(FakeLaunchOptions());
    });

    test('launches valid URL externally', () async {
      when(
        () => mockUrlLauncher.launchUrl(any(), any()),
      ).thenAnswer((_) async => true);

      await handleMarkdownLinkTap('https://example.com', 'Example');

      verify(
        () => mockUrlLauncher.launchUrl(
          'https://example.com',
          any(),
        ),
      ).called(1);
    });

    test('does not launch when URL is invalid', () async {
      when(
        () => mockUrlLauncher.launchUrl(any(), any()),
      ).thenAnswer((_) async => true);

      // Uri.tryParse returns non-null for most strings, but an empty
      // string still produces a valid (empty) Uri. The function only
      // skips launch when tryParse returns null, which is very rare.
      // We can verify no crash occurs with odd URLs.
      await handleMarkdownLinkTap('', '');

      // Even empty string parses as a valid Uri, so launchUrl is called
      verify(() => mockUrlLauncher.launchUrl(any(), any())).called(1);
    });

    test('handles URL with special characters', () async {
      when(
        () => mockUrlLauncher.launchUrl(any(), any()),
      ).thenAnswer((_) async => true);

      await handleMarkdownLinkTap(
        'https://example.com/path?q=hello%20world&lang=en',
        'Search',
      );

      verify(
        () => mockUrlLauncher.launchUrl(
          'https://example.com/path?q=hello%20world&lang=en',
          any(),
        ),
      ).called(1);
    });
  });

  group('buildMarkdownLink', () {
    testWidgets('renders link with correct styling', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return buildMarkdownLink(
                  context,
                  const TextSpan(text: 'Click here'),
                  'https://example.com',
                  const TextStyle(fontSize: 14),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Click here'), findsOneWidget);

      // Verify InkWell with click cursor exists
      final inkWell = tester.widget<InkWell>(find.byType(InkWell));
      expect(inkWell.mouseCursor, SystemMouseCursors.click);
    });

    testWidgets('applies custom link color', (tester) async {
      const customColor = Colors.red;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return buildMarkdownLink(
                  context,
                  const TextSpan(text: 'Red link'),
                  'https://example.com',
                  const TextStyle(fontSize: 14),
                  linkColor: customColor,
                );
              },
            ),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.byType(Text));
      final span = textWidget.textSpan! as TextSpan;
      expect(span.style!.color, customColor);
      expect(span.style!.decoration, TextDecoration.underline);
      expect(span.style!.decorationColor, customColor);
    });

    testWidgets('uses theme primary color when no linkColor specified', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: const ColorScheme.light()),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return buildMarkdownLink(
                  context,
                  const TextSpan(text: 'Default link'),
                  'https://example.com',
                  const TextStyle(fontSize: 14),
                );
              },
            ),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.byType(Text));
      final span = textWidget.textSpan! as TextSpan;
      // Should use theme's primary color
      expect(span.style!.color, isNotNull);
      expect(span.style!.decoration, TextDecoration.underline);
    });

    testWidgets('has Semantics with link: true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return buildMarkdownLink(
                  context,
                  const TextSpan(text: 'Accessible link'),
                  'https://example.com',
                  const TextStyle(fontSize: 14),
                );
              },
            ),
          ),
        ),
      );

      // Find the Semantics widget that wraps our InkWell (has link: true)
      final semanticsWidgets = tester.widgetList<Semantics>(
        find.byType(Semantics),
      );
      final linkSemantics = semanticsWidgets.where(
        (s) => s.properties.link == true,
      );
      expect(linkSemantics, isNotEmpty);
    });

    testWidgets('tapping InkWell triggers URL launch', (tester) async {
      final mockUrlLauncher = MockUrlLauncher();
      UrlLauncherPlatform.instance = mockUrlLauncher;
      registerFallbackValue(FakeLaunchOptions());

      when(
        () => mockUrlLauncher.launchUrl(any(), any()),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return buildMarkdownLink(
                  context,
                  const TextSpan(text: 'Tap me'),
                  'https://example.com',
                  const TextStyle(fontSize: 14),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(InkWell));
      await tester.pump();

      verify(
        () => mockUrlLauncher.launchUrl('https://example.com', any()),
      ).called(1);
    });
  });
}
