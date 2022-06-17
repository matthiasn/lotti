// modified from https://github.com/cph-cachet/research.package/blob/master/example/lib/linear_survey_page.dart
import 'dart:convert';

import 'package:auto_route/annotations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/surveys/run_surveys.dart';
import 'package:lotti/theme.dart';
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
    return SizedBox(
      height: 440,
      child: Flex(
        direction: Axis.horizontal,
        children: [
          Flexible(
            child: Theme(
              data: ThemeData(
                primaryColor: Colors.lightBlue[800],
                fontFamily: 'Oswald',

                // Define the default `TextTheme`. Use this to specify the default
                // text styling for headlines, titles, bodies of text, and more.
                textTheme: TextTheme(
                  headline3: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  headline5: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w100,
                  ),
                  headline6: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[800],
                  ),
                ),
              ),
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
          ),
        ],
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
      backgroundColor: AppColors.bodyBgColor,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Button(
                'CFQ 11',
                onPressed: () => runCfq11(linkedId: linkedId, context: context),
                primaryColor: CupertinoColors.systemOrange,
              ),
              Button(
                'PANAS',
                onPressed: () => runPanas(linkedId: linkedId, context: context),
                primaryColor: CupertinoColors.systemOrange,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FillSurveyWithTypePage extends StatelessWidget {
  const FillSurveyWithTypePage({
    super.key,
    @PathParam() this.surveyType,
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
    @PathParam() this.linkedId,
  });

  final String? linkedId;

  @override
  Widget build(BuildContext context) {
    return FillSurveyPage(
      linkedId: linkedId,
    );
  }
}
