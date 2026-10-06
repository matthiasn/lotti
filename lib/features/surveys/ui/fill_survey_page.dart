// modified from https://github.com/cph-cachet/research.package/blob/master/example/lib/linear_survey_page.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/surveys/ui/survey_localizations.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:research_package/research_package.dart';

/// Hosts a `research_package` `RPUITask` inside the survey modal.
///
/// On submit it invokes [resultCallback] (scoring + persistence). On cancel it
/// only logs that the survey was cancelled and how many step results it had —
/// never the answers, which are the user's own content. Cancelled surveys are
/// never persisted, so only submitted surveys become journal data. Adapted
/// from research.package's `linear_survey_page` example.
class SurveyWidget extends ConsumerWidget {
  const SurveyWidget(this.task, this.resultCallback, {super.key});

  final RPOrderedTask task;
  final void Function(RPTaskResult) resultCallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            ref
                .read(domainLoggerProvider)
                .log(
                  LogDomain.general,
                  result == null
                      ? 'Survey cancelled without a result'
                      : 'Survey cancelled with '
                            '${result.results.length} step results',
                  subDomain: 'SurveyWidget',
                );
          },
        ),
      ),
    );
  }
}
