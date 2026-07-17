import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:research_package/research_package.dart';

/// Localizes the navigation and validation copy rendered by `research_package`.
///
/// The package ships only a few of Lotti's supported locales. Loading these
/// labels from [AppLocalizations] prevents a Czech, German, or Romanian survey
/// from suddenly reverting to English for its progress controls or dismissal
/// confirmation.
final List<LocalizationsDelegate<dynamic>> surveyLocalizationsDelegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  RPLocalizationsDelegate(loaders: [_SurveyLocalizationLoader()]),
];

class _SurveyLocalizationLoader implements LocalizationLoader {
  @override
  Future<Map<String, String>> load(Locale locale) async {
    final messages = await AppLocalizations.delegate.load(locale);

    return {
      'BACK': messages.surveyBackButton,
      'CANCEL': messages.cancelButton,
      'DONE': messages.doneButton,
      'NEXT': messages.surveyNextButton,
      'NO': messages.surveyNoButton,
      'YES': messages.surveyYesButton,
      'of': messages.surveyProgressOf,
      'cancel_confirmation': messages.surveyCancelConfirmation,
      'discard_confirmation': messages.surveyDiscardConfirmation,
      'choose_one_option': messages.surveyChooseOneOption,
      'choose_one_or_more_options': messages.surveyChooseOneOrMoreOptions,
      'input_number': messages.surveyInputNumberValidation,
      'tap_to_answer': messages.surveyTapToAnswer,
      'between': messages.surveyValueBetween,
      'and': messages.surveyValueAnd,
    };
  }
}
