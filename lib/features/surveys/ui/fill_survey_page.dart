// modified from https://github.com/cph-cachet/research.package/blob/master/example/lib/linear_survey_page.dart
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/surveys/tools/run_surveys.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
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
    return Container(
      constraints: const BoxConstraints(maxHeight: 500),
      padding: const EdgeInsets.only(bottom: 20, left: 10, right: 10),
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
    return Scaffold(
      appBar: TitleAppBar(title: context.messages.addSurveyTitle),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            RoundedButton(
              'CFQ 11',
              onPressed: () => runCfq11(
                linkedId: linkedId,
                context: context,
                themeData: Theme.of(context),
              ),
              primaryColor: CupertinoColors.systemOrange,
            ),
            const SizedBox(height: 20),
            RoundedButton(
              'PANAS',
              onPressed: () => runPanas(
                linkedId: linkedId,
                context: context,
                themeData: Theme.of(context),
              ),
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
