import 'package:flutter/widgets.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_en.dart';

/// Localized strings for copy rendered **outside the widget tree**.
///
/// `context.messages` is the way to reach localizations everywhere a
/// `BuildContext` exists. Producers of OS notifications and durable
/// notification rows have none: they run from sync observers, background job
/// callbacks and agent wakes, so they resolve the device locale directly.
///
/// The locale is read through the binding's dispatcher rather than the global
/// `PlatformDispatcher` singleton, so it follows the recognised,
/// test-overridable locale source. A locale the app ships no catalog for
/// falls back to English rather than throwing — copy in the wrong language is
/// a far smaller failure than a notification that never fires.
AppLocalizations deviceMessages() {
  final locale = WidgetsBinding.instance.platformDispatcher.locale;
  return AppLocalizations.delegate.isSupported(locale)
      ? lookupAppLocalizations(locale)
      : AppLocalizationsEn();
}
