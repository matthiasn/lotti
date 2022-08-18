import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/pages/create/create_measurement_page.dart';
import 'package:lotti/pages/create/fill_survey_page.dart';
import 'package:lotti/pages/create/record_audio_page.dart';
import 'package:lotti/pages/journal/entry_details_page.dart';
import 'package:lotti/pages/journal/journal_page.dart';

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

    return [
      const BeamPage(
        key: ValueKey('journal'),
        title: 'Journal',
        type: BeamPageType.noTransition,
        child: JournalPage(),
      ),
      if (pathContainsKey('entryId'))
        BeamPage(
          key: ValueKey('journal-${state.pathParameters['entryId']}'),
          child: EntryDetailPage(
            itemId: state.pathParameters['entryId']!,
          ),
        ),
      if (pathContains('fill_survey/') && pathContainsKey('surveyType'))
        BeamPage(
          key: ValueKey('fill_survey-${state.pathParameters['surveyType']}'),
          child: FillSurveyWithTypePage(
            surveyType: state.pathParameters['surveyType'],
          ),
        ),
      if (pathContains('fill_survey_linked/') && pathContainsKey('linkedId'))
        BeamPage(
          key: ValueKey(
            'fill_survey_linked-${state.pathParameters['linkedId']}',
          ),
          child: FillSurveyWithLinkedPage(
            linkedId: state.pathParameters['linkedId'],
          ),
        ),
      if (pathContains('record_audio/') && pathContainsKey('linkedId'))
        BeamPage(
          key: ValueKey('journal-${state.pathParameters['linkedId']}'),
          child: RecordAudioPage(
            linkedId: state.pathParameters['linkedId'],
          ),
        ),
      if (pathContains('measure_linked/') && pathContainsKey('linkedId'))
        BeamPage(
          key: ValueKey('measure_linked-${state.pathParameters['linkedId']}'),
          child: CreateMeasurementWithLinkedPage(
            linkedId: state.pathParameters['linkedId'],
          ),
        ),
      if (pathContains('measure/') && pathContainsKey('selectedId'))
        BeamPage(
          key:
              ValueKey('journal-measure-${state.pathParameters['selectedId']}'),
          child: CreateMeasurementWithTypePage(
            selectedId: state.pathParameters['selectedId'],
          ),
        ),
    ];
  }
}
