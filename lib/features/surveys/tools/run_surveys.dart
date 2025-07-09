import 'package:flutter/material.dart';
import 'package:lotti/features/surveys/definitions/cfq11_survey.dart';
import 'package:lotti/features/surveys/definitions/ghq12_survey.dart';
import 'package:lotti/features/surveys/definitions/panas_survey.dart';
import 'package:lotti/features/surveys/tools/calculate.dart';
import 'package:lotti/features/surveys/ui/fill_survey_page.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/modals.dart';
import 'package:research_package/research_package.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

Future<void> runSurvey({
  required RPOrderedTask task,
  required ThemeData themeData,
  required void Function(RPTaskResult) resultCallback,
  required BuildContext context,
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  await WoltModalSheet.show<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    modalBarrierColor: isDark
        ? context.colorScheme.surfaceContainerLow.withAlpha(128)
        : context.colorScheme.outline.withAlpha(128),
    pageListBuilder: (modalSheetContext) {
      return [
        ModalUtils.modalSheetPage(
          context: context,
          backgroundColor: themeData.canvasColor,
          isTopBarLayerAlwaysVisible: false,
          showCloseButton: false,
          child: Theme(
            data: themeData.copyWith(
              scaffoldBackgroundColor: Colors.transparent,
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  foregroundColor: themeData.colorScheme.onPrimary,
                ),
              ),
              textTheme: themeData.textTheme.copyWith(
                bodyLarge: themeData.textTheme.bodyMedium,
                headlineSmall: themeData.textTheme.bodyLarge,
              ),
            ),
            child: SurveyWidget(task, resultCallback),
          ),
        ),
      ];
    },
    modalTypeBuilder: ModalUtils.modalTypeBuilder,
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
