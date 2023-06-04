import 'package:flutter/material.dart';
import 'package:lotti/pages/create/fill_survey_page.dart';
import 'package:lotti/surveys/calculate.dart';
import 'package:lotti/surveys/cfq11_survey.dart';
import 'package:lotti/surveys/panas_survey.dart';
import 'package:lotti/themes/theme.dart';
import 'package:research_package/research_package.dart';

Future<void> runSurvey({
  required RPOrderedTask task,
  required ThemeData themeData,
  required void Function(RPTaskResult) resultCallback,
  required BuildContext context,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    builder: (BuildContext context) {
      final textColor = themeData.textTheme.titleMedium?.color ?? Colors.grey;

      return Theme(
        data: themeData.copyWith(
          scaffoldBackgroundColor: Colors.transparent,
          textTheme: Theme.of(context)
              .textTheme
              .apply(
                fontFamily: 'PlusJakartaSans',
              )
              .copyWith(
                // TODO: remove deprecated usage
                // ignore: deprecated_member_use
                headline3: TextStyle(
                  fontSize: fontSizeLarge,
                  fontFamily: 'PlusJakartaSans',
                  color: textColor,
                ),
                // TODO: remove deprecated usage
                // ignore: deprecated_member_use
                headline5: TextStyle(
                  fontSize: fontSizeMedium,
                  color: textColor,
                  fontFamily: 'PlusJakartaSans',
                ),
                // TODO: remove deprecated usage
                // ignore: deprecated_member_use
                headline6: TextStyle(
                  color: textColor,
                  fontSize: fontSizeMedium,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
        ),
        child: SurveyWidget(task, resultCallback),
      );
    },
  );
}

void runCfq11({
  required BuildContext context,
  required ThemeData themeData,
  String? linkedId,
}) {
  runSurvey(
    context: context,
    task: cfq11SurveyTask,
    themeData: themeData,
    resultCallback: createResultCallback(
      scoreDefinitions: cfq11ScoreDefinitions,
      context: context,
      linkedId: linkedId,
    ),
  );
}

void runPanas({
  required BuildContext context,
  required ThemeData themeData,
  String? linkedId,
}) {
  runSurvey(
    context: context,
    task: panasSurveyTask,
    themeData: themeData,
    resultCallback: createResultCallback(
      scoreDefinitions: panasScoreDefinitions,
      context: context,
      linkedId: linkedId,
    ),
  );
}
