import 'package:flutter/material.dart';
import 'package:lotti/pages/create/fill_survey_page.dart';
import 'package:lotti/surveys/calculate.dart';
import 'package:lotti/surveys/cfq11_survey.dart';
import 'package:lotti/surveys/panas_survey.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:research_package/research_package.dart';

Future<void> runSurvey({
  required RPOrderedTask task,
  required void Function(RPTaskResult) resultCallback,
  required BuildContext context,
}) async {
  await showCupertinoModalBottomSheet<void>(
    duration: isTestEnv ? Duration.zero : const Duration(seconds: 1),
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(16),
      ),
    ),
    backgroundColor: styleConfig().cardColor,
    clipBehavior: Clip.antiAliasWithSaveLayer,
    useRootNavigator: true,
    builder: (BuildContext context) {
      return SurveyWidget(task, resultCallback);
    },
  );
}

void runCfq11({
  required BuildContext context,
  String? linkedId,
}) {
  runSurvey(
    context: context,
    task: cfq11SurveyTask,
    resultCallback: createResultCallback(
      scoreDefinitions: cfq11ScoreDefinitions,
      context: context,
      linkedId: linkedId,
    ),
  );
}

void runPanas({
  required BuildContext context,
  String? linkedId,
}) {
  runSurvey(
    context: context,
    task: panasSurveyTask,
    resultCallback: createResultCallback(
      scoreDefinitions: panasScoreDefinitions,
      context: context,
      linkedId: linkedId,
    ),
  );
}
