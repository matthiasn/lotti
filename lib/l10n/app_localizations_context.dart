import 'package:flutter/widgets.dart';
import 'package:lotti/l10n/app_localizations.dart';

extension LocalizedBuildContext on BuildContext {
  AppLocalizations get messages => AppLocalizations.of(this)!;
}
