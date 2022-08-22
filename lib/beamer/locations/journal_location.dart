import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/pages/create/create_measurement_page.dart';
import 'package:lotti/pages/create/fill_survey_page.dart';
import 'package:lotti/pages/create/record_audio_page.dart';
import 'package:lotti/pages/journal/entry_details_page.dart';
import 'package:lotti/pages/journal/journal_page.dart';
import 'package:lotti/utils/uuid.dart';

class JournalLocation extends BeamLocation<BeamState> {
  JournalLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => [
        '/journal/:entryId',
        '/journal/fill_survey/:surveyType',
        '/journal/fill_survey_linked/:linkedId',
        '/journal/record_audio/:linkedId',
        '/journal/measure_linked/:linkedId',
        '/journal/measure/:selectedId',
      ];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    bool pathContains(String s) => state.uri.path.contains(s);
    bool pathContainsKey(String s) => state.pathParameters.containsKey(s);

    final entryId = state.pathParameters['entryId'];
    final linkedId = state.pathParameters['linkedId'];
    final selectedId = state.pathParameters['selectedId'];

    return [
      const BeamPage(
        key: ValueKey('journal'),
        title: 'Journal',
        type: BeamPageType.noTransition,
        child: JournalPage(),
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
      if (pathContains('fill_survey_linked/'))
        BeamPage(
          key: ValueKey('fill_survey_linked-$linkedId'),
          child: FillSurveyWithLinkedPage(linkedId: linkedId),
        ),
      if (pathContains('record_audio/'))
        BeamPage(
          key: ValueKey('journal-$linkedId'),
          child: RecordAudioPage(linkedId: linkedId),
        ),
      if (pathContains('measure_linked/'))
        BeamPage(
          key: ValueKey('measure_linked-$linkedId'),
          child: CreateMeasurementWithLinkedPage(linkedId: linkedId),
        ),
      if (pathContains('measure/') && isUuid('selectedId'))
        BeamPage(
          key: ValueKey('journal-measure-$selectedId'),
          child: CreateMeasurementWithTypePage(selectedId: selectedId),
        ),
    ];
  }
}
