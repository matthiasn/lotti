import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/pages/create/fill_survey_page.dart';
import 'package:lotti/pages/create/record_audio_page.dart';
import 'package:lotti/pages/journal/entry_details_page.dart';
import 'package:lotti/pages/journal/infinite_journal_page.dart';
import 'package:lotti/utils/uuid.dart';

class JournalLocation extends BeamLocation<BeamState> {
  JournalLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => [
        '/journal/:entryId',
        '/journal/:entryId/record_audio/:linkedId',
        '/journal/fill_survey/:surveyType',
      ];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    bool pathContains(String s) => state.uri.path.contains(s);
    bool pathContainsKey(String s) => state.pathParameters.containsKey(s);

    final entryId = state.pathParameters['entryId'];
    final linkedId = state.pathParameters['linkedId'];

    return [
      const BeamPage(
        key: ValueKey('journal'),
        title: 'Journal',
        type: BeamPageType.noTransition,
        child: InfiniteJournalPage(),
      ),
      if (isUuid(entryId))
        BeamPage(
          key: ValueKey('journal-$entryId'),
          child: EntryDetailPage(itemId: entryId!),
        ),
      if (pathContains('fill_survey/') && pathContainsKey('surveyType'))
        BeamPage(
          key: ValueKey('fill_survey-${state.pathParameters['surveyType']}'),
          child: FillSurveyWithTypePage(
            surveyType: state.pathParameters['surveyType'],
          ),
        ),
      if (pathContains('record_audio/'))
        BeamPage(
          key: ValueKey('record_audio-$linkedId'),
          child: RecordAudioPage(linkedId: linkedId),
        ),
    ];
  }
}
