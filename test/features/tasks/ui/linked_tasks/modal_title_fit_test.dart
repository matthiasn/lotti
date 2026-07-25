import 'dart:io';

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

  /// Strings must fit unscaled. Beyond that the shared modal title is bounded
  /// to one line with an ellipsis (ModalUtils._modalTitle), so a large text
  /// scale degrades predictably instead of reflowing or clipping the bar —
  /// which is the defect this guard exists for. Asserted separately below.
  const textScales = [1.0];

  test('the shared modal title degrades to one ellipsized line', () {
    // The strings above fit unscaled; at large accessibility text sizes no
    // string can. What must never happen is a silent second line in a fixed
    // height bar, so the component itself has to bound it.
    final source = File(
      'lib/widgets/modal/modal_utils.dart',
    ).readAsStringSync();
    final title = source.substring(
      source.indexOf('static Widget _modalTitle'),
      source.indexOf('static DsTokens _tokens'),
    );
    expect(title, contains('maxLines: 1'));
    expect(title, contains('overflow: TextOverflow.ellipsis'));
  });

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
        for (final scale in textScales) {
          final painter = TextPainter(
            text: TextSpan(
              text: entry.value,
              // The shipped style, letterSpacing included: omitting it
              // under-reports by ~3pt on ~5pt of headroom, which is an error
              // two thirds the size of the margin being measured.
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.25,
              ),
            ),
            textDirection: TextDirection.ltr,
            textScaler: TextScaler.linear(scale),
            maxLines: 2,
          )..layout(maxWidth: titleBoxWidth);

          expect(
            painter.computeLineMetrics().length,
            1,
            reason:
                '$localeName/${entry.key} "${entry.value}" needs '
                '${painter.computeLineMetrics().length} lines in '
                '${titleBoxWidth}pt at text scale $scale — shorten the '
                'string, it will reflow or clip the modal bar',
          );
        }
      }
    });
  }
}
