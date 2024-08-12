import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/audio/recorder_cubit.dart';
import 'package:lotti/blocs/audio/recorder_state.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/widgets/create/add_actions.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';

import '../../helpers/path_provider.dart';
import '../../mocks/mocks.dart';
import '../../test_data/test_data.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerFallbackValue(FakeEntryText());
  registerFallbackValue(FakeTaskData());
  registerFallbackValue(FakeJournalEntity());

  group('RadialAddActionButtons Widget Tests - ', () {
    final mockNavService = MockNavService();
    final mockPersistenceLogic = MockPersistenceLogic();
    final mockTimeService = MockTimeService();
    final mockJournalDb = MockJournalDb();

    setUp(() async {
      setFakeDocumentsPath();

      getIt
        ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
        ..registerSingleton<NavService>(mockNavService)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<TimeService>(mockTimeService)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);
    });
    tearDown(getIt.reset);

    testWidgets(
      'add photo icon visible and tappable',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const RadialAddActionButtons(radius: 150),
          ),
        );

        await tester.pumpAndSettle();

        final addIconFinder = find.byIcon(Icons.add_rounded);
        expect(addIconFinder, findsOneWidget);

        final addPhotoIconFinder = find.byIcon(Icons.add_a_photo_outlined);

        await tester.tap(addIconFinder);
        await tester.pumpAndSettle();

        expect(addPhotoIconFinder, findsOneWidget);

        await tester.tap(addPhotoIconFinder);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'add photo icon visible and tappable (with linked)',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            RadialAddActionButtons(
              radius: 150,
              linked: testTextEntry,
            ),
          ),
        );

        await tester.pumpAndSettle();

        final addIconFinder = find.byIcon(Icons.add_rounded);
        expect(addIconFinder, findsOneWidget);

        final addPhotoIconFinder = find.byIcon(Icons.add_a_photo_outlined);

        await tester.tap(addIconFinder);
        await tester.pumpAndSettle();

        expect(addPhotoIconFinder, findsOneWidget);

        await tester.tap(addPhotoIconFinder);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'add text icon visible and tappable, with nav',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const RadialAddActionButtons(radius: 150),
          ),
        );

        when(
          () => mockPersistenceLogic.createTextEntry(
            any(),
            started: any(named: 'started'),
            id: any(named: 'id'),
            linkedId: any(named: 'linkedId'),
          ),
        ).thenAnswer((_) async => testTextEntry);

        await tester.pumpAndSettle();

        final addIconFinder = find.byIcon(Icons.add_rounded);
        expect(addIconFinder, findsOneWidget);

        final addTextIconFinder = find.byIcon(MdiIcons.textLong);

        await tester.tap(addIconFinder);
        await tester.pumpAndSettle();

        expect(addTextIconFinder, findsOneWidget);

        await tester.tap(addTextIconFinder);
        await tester.pumpAndSettle();

        verify(
          () => mockNavService
              .beamToNamed('/journal/32ea936e-dfc6-43bd-8722-d816c35eb489'),
        ).called(1);
      },
    );

    testWidgets(
      'add text icon visible and tappable (with linked) - no nav',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            RadialAddActionButtons(
              radius: 150,
              linked: testTextEntry,
            ),
          ),
        );

        await tester.pumpAndSettle();

        final addIconFinder = find.byIcon(Icons.add_rounded);
        expect(addIconFinder, findsOneWidget);

        final addTextIconFinder = find.byIcon(MdiIcons.textLong);

        await tester.tap(addIconFinder);
        await tester.pumpAndSettle();

        expect(addTextIconFinder, findsOneWidget);

        await tester.tap(addTextIconFinder);
        await tester.pumpAndSettle();

        verifyNever(
          () => mockNavService.beamToNamed(
            '/journal/32ea936e-dfc6-43bd-8722-d816c35eb489',
          ),
        );
      },
    );

    testWidgets(
      'add timer icon invisible without linked entry',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const RadialAddActionButtons(radius: 150),
          ),
        );

        when(
          () => mockPersistenceLogic.createTextEntry(
            any(),
            started: any(named: 'started'),
            id: any(named: 'id'),
            linkedId: any(named: 'linkedId'),
          ),
        ).thenAnswer((_) async => testTextEntry);

        await tester.pumpAndSettle();

        final addIconFinder = find.byIcon(Icons.add_rounded);
        expect(addIconFinder, findsOneWidget);

        final addTimerIconFinder = find.byIcon(MdiIcons.timerOutline);

        await tester.tap(addIconFinder);
        await tester.pumpAndSettle();

        expect(addTimerIconFinder, findsNothing);
      },
    );

    testWidgets(
      'add timer icon visible and tappable (with linked) - no nav',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            RadialAddActionButtons(
              radius: 150,
              linked: testTextEntry,
            ),
          ),
        );

        when(() => mockTimeService.start(any(), any()))
            .thenAnswer((_) async {});

        await tester.pumpAndSettle();

        final addIconFinder = find.byIcon(Icons.add_rounded);
        expect(addIconFinder, findsOneWidget);

        final addTimerIconFinder = find.byIcon(MdiIcons.timerOutline);

        await tester.tap(addIconFinder);
        await tester.pumpAndSettle();

        expect(addTimerIconFinder, findsOneWidget);

        await tester.tap(addTimerIconFinder);
        await tester.pumpAndSettle();

        verify(() => mockTimeService.start(any(), any())).called(1);
        verifyNever(() => mockNavService.beamToNamed(any()));
      },
    );

    testWidgets(
      'add task icon visible and tappable, with nav',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const RadialAddActionButtons(radius: 150),
          ),
        );

        when(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
          ),
        ).thenAnswer((_) async => testTask);

        await tester.pumpAndSettle();

        final addIconFinder = find.byIcon(Icons.add_rounded);
        expect(addIconFinder, findsOneWidget);

        final addTaskIconFinder = find.byIcon(Icons.task_outlined);

        await tester.tap(addIconFinder);
        await tester.pumpAndSettle();

        expect(addTaskIconFinder, findsOneWidget);

        await tester.tap(addTaskIconFinder);
        await tester.pumpAndSettle();

        verify(
          () => mockNavService
              .beamToNamed('/journal/79ef5021-12df-4651-ac6e-c9a5b58a859c'),
        ).called(1);
      },
    );

    testWidgets(
      'add screenshot icon is not shown when not on mac',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const RadialAddActionButtons(radius: 150),
          ),
        );

        await tester.pumpAndSettle();

        final addIconFinder = find.byIcon(Icons.add_rounded);
        expect(addIconFinder, findsOneWidget);

        final addScreenIconFinder = find.byIcon(MdiIcons.monitorScreenshot);

        await tester.tap(addIconFinder);
        await tester.pumpAndSettle();

        expect(addScreenIconFinder, findsNothing);
      },
    );

    testWidgets(
      'add screenshot icon is visible and tappable on mac',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const RadialAddActionButtons(
              radius: 150,
              isMacOS: true,
            ),
          ),
        );

        when(
          () => mockJournalDb.getConfigFlag(any()),
        ).thenAnswer((_) async => true);

        await tester.pumpAndSettle();

        final addIconFinder = find.byIcon(Icons.add_rounded);
        expect(addIconFinder, findsOneWidget);

        final addScreenIconFinder = find.byIcon(MdiIcons.monitorScreenshot);

        await tester.tap(addIconFinder);
        await tester.pumpAndSettle();

        expect(addScreenIconFinder, findsOneWidget);

        await tester.tap(addScreenIconFinder);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'add audio icon is shown',
      (tester) async {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const RadialAddActionButtons(radius: 150),
          ),
        );

        await tester.pumpAndSettle();

        final addIconFinder = find.byIcon(Icons.add_rounded);
        expect(addIconFinder, findsOneWidget);

        final addAudioIconFinder = find.byIcon(Icons.mic_rounded);

        await tester.tap(addIconFinder);
        await tester.pumpAndSettle();

        expect(addAudioIconFinder, findsOneWidget);
      },
    );

    testWidgets(
      'add audio icon is visible and tappable on iOS',
      (tester) async {
        final mockAudioRecorderCubit = MockAudioRecorderCubit();

        when(() => mockAudioRecorderCubit.stream).thenAnswer(
          (_) => Stream<AudioRecorderState>.fromIterable([initialState]),
        );

        when(mockAudioRecorderCubit.record).thenAnswer(
          (_) async {},
        );

        when(mockAudioRecorderCubit.close).thenAnswer(
          (_) async {},
        );

        when(mockNavService.tasksTabActive).thenAnswer(
          (_) => false,
        );

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            BlocProvider<AudioRecorderCubit>(
              create: (BuildContext context) => mockAudioRecorderCubit,
              child: const RadialAddActionButtons(
                radius: 150,
                isIOS: true,
              ),
            ),
          ),
        );

        when(
          () => mockJournalDb.getConfigFlag(any()),
        ).thenAnswer((_) async => true);

        await tester.pumpAndSettle();

        final addIconFinder = find.byIcon(Icons.add_rounded);
        expect(addIconFinder, findsOneWidget);

        final addAudioIconFinder = find.byIcon(Icons.mic_rounded);

        await tester.tap(addIconFinder);
        await tester.pumpAndSettle();

        expect(addAudioIconFinder, findsOneWidget);

        await tester.tap(addAudioIconFinder);
        await tester.pumpAndSettle();

        verify(
          () => mockNavService.beamToNamed('/journal/null/record_audio/null'),
        ).called(1);
      },
    );

    testWidgets(
      'add audio icon is visible and tappable on Android',
      (tester) async {
        final mockAudioRecorderCubit = MockAudioRecorderCubit();

        when(() => mockAudioRecorderCubit.stream).thenAnswer(
          (_) => Stream<AudioRecorderState>.fromIterable([initialState]),
        );

        when(mockAudioRecorderCubit.record).thenAnswer(
          (_) async {},
        );

        when(mockAudioRecorderCubit.close).thenAnswer(
          (_) async {},
        );

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            BlocProvider<AudioRecorderCubit>(
              create: (BuildContext context) => mockAudioRecorderCubit,
              child: const RadialAddActionButtons(
                radius: 150,
                isAndroid: true,
              ),
            ),
          ),
        );

        when(
          () => mockJournalDb.getConfigFlag(any()),
        ).thenAnswer((_) async => true);

        await tester.pumpAndSettle();

        final addIconFinder = find.byIcon(Icons.add_rounded);
        expect(addIconFinder, findsOneWidget);

        final addAudioIconFinder = find.byIcon(Icons.mic_rounded);

        await tester.tap(addIconFinder);
        await tester.pumpAndSettle();

        expect(addAudioIconFinder, findsOneWidget);

        await tester.tap(addAudioIconFinder);
        await tester.pumpAndSettle();

        verify(
          () => mockNavService.beamToNamed('/journal/null/record_audio/null'),
        ).called(1);
      },
    );
  });
}
