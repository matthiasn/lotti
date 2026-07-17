// modified from https://github.com/cph-cachet/research.package/blob/master/example/lib/linear_survey_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/surveys/ui/survey_localizations.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:research_package/research_package.dart';

/// Hosts a `research_package` `RPUITask` inside the survey modal.
///
/// On submit it invokes [resultCallback] (scoring + persistence). On cancel it
/// only logs the partial result via `DevLogger` — cancelled surveys are never
/// persisted, so only submitted surveys become journal data. Adapted from
/// research.package's `linear_survey_page` example.
class SurveyWidget extends StatelessWidget {
  const SurveyWidget(this.task, this.resultCallback, {super.key});

  final RPOrderedTask task;
  final void Function(RPTaskResult) resultCallback;

  String _encode(Object object) =>
      const JsonEncoder.withIndent(' ').convert(object);

  void cancelCallBack(RPTaskResult result) {
    // Do anything with the result at the moment of the cancellation
    DevLogger.log(
      name: 'SurveyWidget',
      message: 'The result so far:\n${_encode(result)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.designTokens.spacing;
    final maxSurveyHeight =
        spacing.step13 + spacing.step13 + spacing.step13 + spacing.step11;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxSurveyHeight),
      child: Localizations.override(
        context: context,
        delegates: surveyLocalizationsDelegates,
        child: RPUITask(
          task: task,
          onSubmit: resultCallback,
          onCancel: (RPTaskResult? result) {
            if (result == null) {
              DevLogger.log(name: 'SurveyWidget', message: 'No result');
            } else {
              cancelCallBack(result);
            }
          },
        ),
      ),
    );
  }
}
