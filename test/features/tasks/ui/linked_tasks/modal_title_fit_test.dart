import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/l10n/app_localizations.dart';

import '../../../../test_utils/screenshot_harness.dart';

/// Every modal title in this feature must fit one line at phone width, in
/// every shipped locale.
///
/// The modal's top bar is a fixed height with a close button mirrored on the
/// leading side, so a title that needs two lines silently reflows the bar or
/// clips mid-word. That happened once already — in English — and the longer
/// locales run half again as long as English while no screenshot review ever
/// sees them.
void main() {
  setUpAll(loadAppFonts);

  /// Width the title box actually gets: the sheet, less the close button's
  /// tap target and the same reserve mirrored on the leading edge.
  final titleBoxWidth = ScreenshotViewport.phone.width - (2 * 80);

  const locales = ['en', 'de', 'fr', 'es', 'ro', 'cs'];

  for (final localeName in locales) {
    test('modal titles fit one line at phone width in "$localeName"', () async {
      final messages = await AppLocalizations.delegate.load(
        Locale(localeName),
      );

      final titles = <String, String>{
        'linkExistingTaskTitle': messages.linkExistingTaskTitle,
        'createNewLinkedTaskTitle': messages.createNewLinkedTaskTitle,
        'taskBlockerPickerTitle': messages.taskBlockerPickerTitle,
        'editLinkTypeTitle': messages.editLinkTypeTitle,
      };

      for (final entry in titles.entries) {
        final painter = TextPainter(
          text: TextSpan(
            text: entry.value,
            // Matches ModalUtils.modalTitleStyle's size and weight.
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 2,
        )..layout(maxWidth: titleBoxWidth);

        expect(
          painter.computeLineMetrics().length,
          1,
          reason:
              '$localeName/${entry.key} "${entry.value}" needs '
              '${painter.computeLineMetrics().length} lines in '
              '${titleBoxWidth}pt — shorten the string, it will reflow or '
              'clip the modal bar',
        );
      }
    });
  }
}
