import 'package:auto_route/auto_route.dart';
import 'package:lotti/pages/create/create_measurement_page.dart';
import 'package:lotti/pages/create/create_text_entry_page.dart';
import 'package:lotti/pages/create/fill_survey_page.dart';
import 'package:lotti/pages/create/record_audio_page.dart';
import 'package:lotti/pages/journal/entry_details_page.dart';
import 'package:lotti/pages/journal_page.dart';

const AutoRoute journalRoutes = AutoRoute(
  path: 'journal',
  name: 'JournalRouter',
  page: EmptyRouterPage,
  children: [
    AutoRoute(
      path: '',
      page: JournalPage,
    ),
    AutoRoute(
      path: ':itemId',
      page: EntryDetailPage,
    ),
    AutoRoute(
      path: 'create/:linkedId',
      page: CreateTextEntryPage,
    ),
    AutoRoute(
      path: 'create_survey/:linkedId',
      page: FillSurveyPage,
    ),
    AutoRoute(
      path: 'record_audio/:linkedId',
      page: RecordAudioPage,
    ),
    AutoRoute(
      path: 'create_measurement_linked/:linkedId',
      page: CreateMeasurementWithLinkedPage,
    ),
  ],
);
