import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/demo/ui/demo_media_download_prompt.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('formatDemoMediaSize', () {
    Future<AppLocalizations> messagesFor(String locale) =>
        AppLocalizations.delegate.load(Locale(locale));

    test('shows megabytes to one decimal, rounded up so the size is never '
        'understated', () async {
      final en = await messagesFor('en');

      expect(formatDemoMediaSize(en, 26544434), '26.6 MB');
      expect(formatDemoMediaSize(en, 26500000), '26.5 MB');
      expect(formatDemoMediaSize(en, 1), '0.1 MB');
    });

    test('uses the locale decimal separator and unit', () async {
      expect(formatDemoMediaSize(await messagesFor('de'), 26544434), '26,6 MB');
      expect(formatDemoMediaSize(await messagesFor('fr'), 26544434), '26,6 Mo');
    });
  });

  group('DemoMediaDownloadPrompt', () {
    Future<List<DemoMediaChoice>> pumpPrompt(WidgetTester tester) async {
      final choices = <DemoMediaChoice>[];
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DemoMediaDownloadPrompt(bytes: 26544434, onChoice: choices.add),
        ),
      );
      await tester.pump();
      return choices;
    }

    testWidgets('discloses the size in the message and the download button', (
      tester,
    ) async {
      await pumpPrompt(tester);

      expect(find.text('Download the demo photos?'), findsOneWidget);
      expect(
        find.text(
          'The demo comes with sample photos, a 26.6 MB download. You can '
          'explore without them — blurred previews stand in for the photos.',
        ),
        findsOneWidget,
      );
      expect(find.text('Download (26.6 MB)'), findsOneWidget);
      expect(find.text('Continue without photos'), findsOneWidget);
    });

    testWidgets('each button reports its own choice', (tester) async {
      final choices = await pumpPrompt(tester);

      await tester.tap(find.text('Download (26.6 MB)'));
      await tester.tap(find.text('Continue without photos'));

      expect(choices, [DemoMediaChoice.download, DemoMediaChoice.skip]);
    });
  });

  group('showDemoMediaDownloadPrompt', () {
    testWidgets('returns the tapped choice and closes', (tester) async {
      Future<DemoMediaChoice?>? result;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => result = showDemoMediaDownloadPrompt(
                context,
                bytes: 26544434,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Continue without photos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(await result, DemoMediaChoice.skip);
      expect(find.text('Download the demo photos?'), findsNothing);
    });

    testWidgets('returns null when dismissed without a choice', (
      tester,
    ) async {
      Future<DemoMediaChoice?>? result;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => result = showDemoMediaDownloadPrompt(
                context,
                bytes: 26544434,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      Navigator.of(
        tester.element(find.text('Download the demo photos?')),
      ).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(await result, isNull);
    });
  });
}
