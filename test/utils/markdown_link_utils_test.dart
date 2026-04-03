import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/markdown_link_utils.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../mocks/mocks.dart';

Future<void> _pumpMarkdownLink(
  WidgetTester tester, {
  required String text,
  required String url,
  TextStyle style = const TextStyle(fontSize: 14),
  Color? linkColor,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return buildMarkdownLink(
              context,
              TextSpan(text: text),
              url,
              style,
              linkColor: linkColor,
            );
          },
        ),
      ),
    ),
  );
}

void main() {
  group('handleMarkdownLinkTap', () {
    late MockUrlLauncher mockUrlLauncher;
    late UrlLauncherPlatform originalInstance;

    setUp(() {
      originalInstance = UrlLauncherPlatform.instance;
      mockUrlLauncher = MockUrlLauncher();
      UrlLauncherPlatform.instance = mockUrlLauncher;
      registerFallbackValue(FakeLaunchOptions());
    });

    tearDown(() {
      UrlLauncherPlatform.instance = originalInstance;
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

    test('does not launch when URL is empty', () async {
      await handleMarkdownLinkTap('', '');

      verifyNever(() => mockUrlLauncher.launchUrl(any(), any()));
    });

    test('does not launch when URL has no scheme', () async {
      await handleMarkdownLinkTap('example.com/path', '');

      verifyNever(() => mockUrlLauncher.launchUrl(any(), any()));
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
      await _pumpMarkdownLink(
        tester,
        text: 'Click here',
        url: 'https://example.com',
      );

      expect(find.text('Click here'), findsOneWidget);

      final inkWell = tester.widget<InkWell>(find.byType(InkWell));
      expect(inkWell.mouseCursor, SystemMouseCursors.click);
    });

    testWidgets('applies custom link color', (tester) async {
      const customColor = Colors.red;

      await _pumpMarkdownLink(
        tester,
        text: 'Red link',
        url: 'https://example.com',
        linkColor: customColor,
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
      await _pumpMarkdownLink(
        tester,
        text: 'Default link',
        url: 'https://example.com',
      );

      final textWidget = tester.widget<Text>(find.byType(Text));
      final span = textWidget.textSpan! as TextSpan;
      expect(span.style!.color, isNotNull);
      expect(span.style!.decoration, TextDecoration.underline);
    });

    testWidgets('has Semantics with link: true', (tester) async {
      await _pumpMarkdownLink(
        tester,
        text: 'Accessible link',
        url: 'https://example.com',
      );

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
      final originalInstance = UrlLauncherPlatform.instance;
      UrlLauncherPlatform.instance = mockUrlLauncher;
      registerFallbackValue(FakeLaunchOptions());

      when(
        () => mockUrlLauncher.launchUrl(any(), any()),
      ).thenAnswer((_) async => true);

      addTearDown(() {
        UrlLauncherPlatform.instance = originalInstance;
      });

      await _pumpMarkdownLink(
        tester,
        text: 'Tap me',
        url: 'https://example.com',
      );

      await tester.tap(find.byType(InkWell));
      await tester.pump();

      verify(
        () => mockUrlLauncher.launchUrl('https://example.com', any()),
      ).called(1);
    });
  });
}
