import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/journal/ui/pages/entry_details_page.dart';
import 'package:lotti/features/journal/ui/pages/infinite_journal_page.dart';
import 'package:lotti/features/surveys/ui/fill_survey_page.dart';
import 'package:lotti/utils/uuid.dart';

class JournalLocation extends BeamLocation<BeamState> {
  JournalLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => [
        '/journal',
        '/journal/:entryId',
        '/journal/fill_survey/:surveyType',
      ];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    bool pathContains(String s) => state.uri.path.contains(s);
    bool pathContainsKey(String s) => state.pathParameters.containsKey(s);

    final entryId = state.pathParameters['entryId'];

    return [
      const BeamPage(
        key: ValueKey('journal'),
        title: 'Journal',
        child: InfiniteJournalPage(showTasks: false),
      ),
      if (isUuid(entryId))
        BeamPage(
          key: ValueKey('journal-$entryId'),
          child: EntryDetailsPage(itemId: entryId!),
        ),
      if (pathContains('fill_survey/') && pathContainsKey('surveyType'))
        BeamPage(
          key: ValueKey('fill_survey-${state.pathParameters['surveyType']}'),
          child: FillSurveyWithTypePage(
            surveyType: state.pathParameters['surveyType'],
          ),
        ),
    ];
  }
}
