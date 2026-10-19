import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/utils/download_size.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<AppLocalizations> messagesFor(String locale) =>
      AppLocalizations.delegate.load(Locale(locale));

  test('shows megabytes to one decimal, rounded up so a download is never '
      'understated', () async {
    final en = await messagesFor('en');

    expect(formatDownloadMegabytes(en, 26544434), '26.6 MB');
    expect(formatDownloadMegabytes(en, 26500000), '26.5 MB');
    expect(formatDownloadMegabytes(en, 398361202), '398.4 MB');
    expect(formatDownloadMegabytes(en, 1), '0.1 MB');
  });

  test('uses the locale decimal separator and unit', () async {
    expect(
      formatDownloadMegabytes(await messagesFor('de'), 26544434),
      '26,6 MB',
    );
    expect(
      formatDownloadMegabytes(await messagesFor('fr'), 26544434),
      '26,6 Mo',
    );
  });
}
