import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/speech/state/app_settings_opener.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recording_origin.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../../mocks/mocks.dart';
import '../../../../../../test_data/test_data.dart';
import '../../../../../../widget_test_utils.dart';
import '../../../../../relationships/helpers/check_in_speech_fakes.dart';

/// The task every strip test records for.
final Task stripSubject = testTask;
final String stripSubjectId = testTask.meta.id;
final String stripSubjectRoute = '/tasks/${testTask.meta.id}';

/// Everything the recording strip's widgets read, scriptable: the app-wide
/// recorder ([FakeAudioRecorderController]), a navigation service whose
/// route on screen a test can move, the journal the subject is read
/// from, and the repository Undo deletes through. The session, the tray and
/// the receipt are the real ones. Move the route on screen through [route].
class StripBench {
  StripBench({
    FakeAudioRecorderController? recorder,
    String route = '/calendar',
  }) : recorder = recorder ?? FakeAudioRecorderController(),
       _route = ValueNotifier<String>(route) {
    when(() => nav.activeRoute).thenAnswer((_) => _route.value);
    when(() => nav.activeRouteChanges).thenReturn(_route);
    when(() => nav.canBeamTo(any())).thenReturn(true);
    when(
      () => db.journalEntityById(stripSubjectId),
    ).thenAnswer((_) async => stripSubject);
    when(
      () => repository.deleteJournalEntity(any()),
    ).thenAnswer((_) async => true);
  }

  final FakeAudioRecorderController recorder;
  final ValueNotifier<String> _route;
  final nav = MockNavService();
  final db = MockJournalDb();
  final repository = MockJournalRepository();
  int settingsOpened = 0;

  /// The route on screen; setting it moves it, as navigating would.
  String get route => _route.value;
  set route(String route) => _route.value = route;

  List<Override> get overrides => [
    audioRecorderControllerProvider.overrideWith(() => recorder),
    navServiceProvider.overrideWithValue(nav),
    journalDbProvider.overrideWithValue(db),
    journalRepositoryProvider.overrideWithValue(repository),
    appSettingsOpenerProvider.overrideWithValue(() async {
      settingsOpened++;
      return true;
    }),
  ];

  /// Pumps [child] in the shared host with the bench's overrides.
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    MediaQueryData mediaQueryData = phoneMediaQueryData,
    List<Override> extra = const [],
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Material(
          child: Align(alignment: Alignment.bottomCenter, child: child),
        ),
        mediaQueryData: mediaQueryData,
        overrides: [...overrides, ...extra],
      ),
    );
    await tester.pump();
  }

  /// Starts a take on the fake recorder, for the subject — or, as a
  /// [voiceNote], for nothing — started at [route].
  Future<void> startTake(
    WidgetTester tester, {
    bool voiceNote = false,
    String? route,
  }) async {
    final linkedId = voiceNote ? null : stripSubjectId;
    await recorder.record(
      linkedId: linkedId,
      origin: RecordingOrigin(
        route: route ?? stripSubjectRoute,
        subjectId: linkedId,
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  void dispose() => _route.dispose();
}
