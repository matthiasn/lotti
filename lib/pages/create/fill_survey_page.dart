// modified from https://github.com/cph-cachet/research.package/blob/master/example/lib/linear_survey_page.dart
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/surveys/run_surveys.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/misc/buttons.dart';
import 'package:research_package/research_package.dart';

class SurveyWidget extends StatelessWidget {
  const SurveyWidget(this.task, this.resultCallback, {super.key});

  final RPOrderedTask task;
  final void Function(RPTaskResult) resultCallback;

  String _encode(Object object) =>
      const JsonEncoder.withIndent(' ').convert(object);

  void printWrapped(String text) {
    final pattern = RegExp('.{1,800}'); // 800 is the size of each chunk
    pattern.allMatches(text).forEach((match) => debugPrint(match.group(0)));
  }

  void cancelCallBack(RPTaskResult result) {
    // Do anything with the result at the moment of the cancellation
    debugPrint('The result so far:\n${_encode(result)}');
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        primaryColor: styleConfig().primaryColor,
        scaffoldBackgroundColor: styleConfig().cardColor,
        fontFamily: 'PlusJakartaSans',
        // Define the default `TextTheme`. Use this to specify the default
        // text styling for headlines, titles, bodies of text, and more.

        textTheme: Theme.of(context)
            .textTheme
            .apply(
              bodyColor: styleConfig().primaryTextColor,
              displayColor: styleConfig().primaryTextColor,
            )
            .copyWith(
              // TODO: remove deprecated usage
              // ignore: deprecated_member_use
              headline3: TextStyle(
                fontSize: 24,
                color: styleConfig().primaryTextColor,
              ),
              // TODO: remove deprecated usage
              // ignore: deprecated_member_use
              headline5: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w200,
                color: styleConfig().primaryTextColor,
              ),
              // TODO: remove deprecated usage
              // ignore: deprecated_member_use
              headline6: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w400,
                color: styleConfig().secondaryTextColor,
              ),
              // TODO: remove deprecated usage
              // ignore: deprecated_member_use
              caption: TextStyle(
                color: styleConfig().secondaryTextColor,
              ),
            ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: RPUITask(
            task: task,
            onSubmit: resultCallback,
            onCancel: (RPTaskResult? result) {
              if (result == null) {
                debugPrint('No result');
              } else {
                cancelCallBack(result);
              }
            },
          ),
        ),
      ),
    );
  }
}

class FillSurveyPage extends StatelessWidget {
  const FillSurveyPage({
    super.key,
    this.linkedId,
    this.surveyType,
  });

  final String? linkedId;
  final String? surveyType;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: TitleAppBar(title: localizations.addSurveyTitle),
      backgroundColor: styleConfig().negspace,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            RoundedButton(
              'CFQ 11',
              onPressed: () => runCfq11(linkedId: linkedId, context: context),
              primaryColor: CupertinoColors.systemOrange,
            ),
            const SizedBox(height: 20),
            RoundedButton(
              'PANAS',
              onPressed: () => runPanas(linkedId: linkedId, context: context),
              primaryColor: CupertinoColors.systemOrange,
            ),
          ],
        ),
      ),
    );
  }
}

class FillSurveyWithTypePage extends StatelessWidget {
  const FillSurveyWithTypePage({
    super.key,
    this.surveyType,
  });

  final String? surveyType;

  @override
  Widget build(BuildContext context) {
    return FillSurveyPage(
      surveyType: surveyType,
    );
  }
}

class FillSurveyWithLinkedPage extends StatelessWidget {
  const FillSurveyWithLinkedPage({
    super.key,
    this.linkedId,
  });

  final String? linkedId;

  @override
  Widget build(BuildContext context) {
    return FillSurveyPage(
      linkedId: linkedId,
    );
  }
}
