import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/ui/create/entry_creation_service.dart';
import 'package:lotti/features/projects/ui/widgets/project_action_bar.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../helpers/stub_audio_recorder_controller.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  final project = makeTestProject(
    id: 'project-1',
    title: 'Nest survey',
    categoryId: 'cat-1',
  );
  late MockEntryCreationService creation;
  late List<String> paths;

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    creation = MockEntryCreationService();
    paths = [];
    beamToNamedOverride = paths.add;
    await setUpTestGetIt();
    when(
      () => creation.showAudioRecordingModal(
        any(),
        linkedId: any(named: 'linkedId'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer((_) {});
    when(
      () => creation.createTextEntry(
        linkedId: any(named: 'linkedId'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer((_) async => testTextEntry);
    when(
      () => creation.importImage(
        any(),
        linkedId: any(named: 'linkedId'),
        categoryId: any(named: 'categoryId'),
        analysisTrigger: any(named: 'analysisTrigger'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => creation.showCreateEntryModal(
        any(),
        linkedFromId: any(named: 'linkedFromId'),
        categoryId: any(named: 'categoryId'),
        host: any(named: 'host'),
      ),
    ).thenAnswer((_) async {});
  });

  tearDown(() async {
    beamToNamedOverride = null;
    await tearDownTestGetIt();
  });

  Future<void> pumpBar(
    WidgetTester tester, {
    double width = 800,
    AudioRecorderState? recorder,
  }) async {
    tester.view.physicalSize = Size(width, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      makeTestableWidget(
        Material(child: ProjectActionBar(project: project)),
        mediaQueryData: MediaQueryData(size: Size(width, 400)),
        overrides: [
          entryCreationServiceProvider.overrideWithValue(creation),
          audioRecorderControllerProvider.overrideWith(
            () => StubAudioRecorderController(recorder),
          ),
        ],
      ),
    );
    await tester.pump();
  }

  testWidgets('records first, then a note, an image and the Add sheet — '
      'everything linked to the project, in its category', (tester) async {
    await pumpBar(tester);
    expect(find.byType(DesignSystemGlassStrip), findsOne);

    await tester.tap(find.byKey(ProjectActionBar.audioKey));
    verify(
      () => creation.showAudioRecordingModal(
        any(),
        linkedId: 'project-1',
        categoryId: 'cat-1',
      ),
    ).called(1);

    await tester.tap(find.byKey(ProjectActionBar.imageKey));
    verify(
      () => creation.importImage(
        any(),
        linkedId: 'project-1',
        categoryId: 'cat-1',
        analysisTrigger: any(named: 'analysisTrigger'),
      ),
    ).called(1);

    // The project in hand goes along, so the sheet's project rules hold
    // from its first frame.
    await tester.tap(find.byKey(ProjectActionBar.addKey));
    verify(
      () => creation.showCreateEntryModal(
        any(),
        linkedFromId: 'project-1',
        categoryId: 'cat-1',
        host: project,
      ),
    ).called(1);
  });

  testWidgets('a note is made linked to the project and opens, so the '
      'writing starts at once', (tester) async {
    await pumpBar(tester);

    await tester.tap(find.byKey(ProjectActionBar.noteKey));
    await tester.pump();

    verify(
      () =>
          creation.createTextEntry(linkedId: 'project-1', categoryId: 'cat-1'),
    ).called(1);
    expect(paths, ['/journal/${testTextEntry.meta.id}']);
  });

  testWidgets('a narrow row keeps recording and Add on one line: the image '
      'gives way first, then the note', (tester) async {
    Future<Set<Key>> shown(double width) async {
      await pumpBar(tester, width: width);
      return {
        for (final key in [
          ProjectActionBar.audioKey,
          ProjectActionBar.noteKey,
          ProjectActionBar.imageKey,
          ProjectActionBar.addKey,
        ])
          if (find.byKey(key).evaluate().isNotEmpty) key,
      };
    }

    const pad = 2 * 24.0; // the strip's own side padding, generously
    expect(
      await shown(ProjectActionBar.minWidthForImageButton + pad),
      hasLength(4),
    );
    expect(
      await shown(ProjectActionBar.minWidthForNoteButton + pad),
      isNot(contains(ProjectActionBar.imageKey)),
    );
    final phone = await shown(ProjectActionBar.minWidthForNoteButton - 1);
    expect(phone, {ProjectActionBar.audioKey, ProjectActionBar.addKey});
  });

  testWidgets('the recording pill takes the alert fill while a recording '
      'linked to this project runs, and says so', (tester) async {
    await pumpBar(
      tester,
      recorder: AudioRecorderState(
        status: AudioRecorderStatus.recording,
        progress: Duration.zero,
        vu: -20,
        dBFS: -160,
        showIndicator: false,
        modalVisible: false,
        linkedId: 'project-1',
      ),
    );

    final tokens = tester.element(find.byType(ProjectActionBar)).designTokens;
    final pill = tester.widget<DsGlassPill>(
      find.byKey(ProjectActionBar.audioKey),
    );
    expect(pill.fillColor, tokens.colors.alert.error.defaultColor);
    expect(pill.semanticLabel, 'Audio recording in progress');
  });
}
