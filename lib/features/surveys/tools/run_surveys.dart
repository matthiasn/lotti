import 'package:flutter/material.dart';
import 'package:lotti/features/surveys/definitions/cfq11_survey.dart';
import 'package:lotti/features/surveys/definitions/ghq12_survey.dart';
import 'package:lotti/features/surveys/definitions/panas_survey.dart';
import 'package:lotti/features/surveys/tools/calculate.dart';
import 'package:lotti/features/surveys/ui/fill_survey_page.dart';
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
      // final textColor = themeData.textTheme.titleMedium?.color ?? Colors.grey;

      return Theme(
        data: themeData.copyWith(
          scaffoldBackgroundColor: Colors.transparent,
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              foregroundColor: themeData.colorScheme.onPrimary,
            ),
          ),
          textTheme: themeData.textTheme.apply(
            fontFamily: 'PlusJakartaSans',
          )
          /*  .copyWith(
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
              )*/
          ,
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

void runGhq12({
  required BuildContext context,
  required ThemeData themeData,
  String? linkedId,
}) {
  runSurvey(
    context: context,
    task: ghq12SurveyTask,
    themeData: themeData,
    resultCallback: createResultCallback(
      scoreDefinitions: ghq12ScoreDefinitions,
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
