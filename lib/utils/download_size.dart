import 'package:intl/intl.dart';
import 'package:lotti/l10n/app_localizations.dart';

/// [bytes] as megabytes for a download prompt, rounded UP to one decimal so
/// the size shown never understates the download.
String formatDownloadMegabytes(AppLocalizations messages, int bytes) {
  final tenths = (bytes / 100000).ceil();
  return messages.downloadSizeMegabytes(
    NumberFormat('0.0', messages.localeName).format(tenths / 10),
  );
}
