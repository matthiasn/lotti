import 'package:beamer/beamer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/locations/tasks_location.dart';
import 'package:lotti/features/demo/seed/demo_world.dart';
import 'package:lotti/features/documents/ui/task_document_page.dart';
import 'package:lotti/features/tasks/ui/pages/task_details_page.dart';
import 'package:lotti/features/tasks/ui/pages/tasks_root_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';

import '../../mocks/mocks.dart';

void main() {
  group('TasksLocation', () {
    late MockBuildContext mockBuildContext;

    late MockNavService mockNavService;
    late ValueNotifier<({String taskId, String documentId})?> desktopDocument;

    setUp(() {
      mockBuildContext = MockBuildContext();
      mockNavService = MockNavService();
      desktopDocument = ValueNotifier(null);
      addTearDown(desktopDocument.dispose);
      when(() => mockNavService.isDesktopMode).thenReturn(false);
      when(
        () => mockNavService.desktopTaskDocument,
      ).thenReturn(desktopDocument);
      if (getIt.isRegistered<NavService>()) {
        getIt.unregister<NavService>();
      }
      getIt.registerSingleton<NavService>(mockNavService);
    });

    tearDown(() {
      if (getIt.isRegistered<NavService>()) {
        getIt.unregister<NavService>();
      }
    });

    test('pathPatterns are correct', () {
      final location = TasksLocation(
        RouteInformation(uri: Uri.parse('/tasks')),
      );
      expect(location.pathPatterns, [
        '/tasks',
        '/tasks/:taskId',
        '/tasks/:taskId/documents/:documentId',
      ]);
    });

    test('buildPages builds TasksRootPage', () {
      final routeInformation = RouteInformation(uri: Uri.parse('/tasks'));
      final location = TasksLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 1);
      expect(pages[0].key, isA<ValueKey<String>>());
      expect(pages[0].child, isA<TasksRootPage>());
    });

    test('buildPages builds TaskDetailsPage', () {
      final taskId = const Uuid().v4();
      final routeInformation = RouteInformation(
        uri: Uri.parse('/tasks/$taskId'),
      );
      final location = TasksLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(
        routeInformation,
      );
      final newPathParameters = Map<String, String>.from(
        beamState.pathParameters,
      );
      newPathParameters['taskId'] = taskId;
      final newBeamState = beamState.copyWith(
        pathParameters: newPathParameters,
      );
      final pages = location.buildPages(
        mockBuildContext,
        newBeamState,
      );
      expect(pages.length, 2);
      expect(pages[0].key, isA<ValueKey<String>>());
      expect(pages[0].child, isA<TasksRootPage>());
      expect(pages[1].key, isA<ValueKey<String>>());
      expect(pages[1].child, isA<TaskDetailsPage>());
      final taskDetailsPage = pages[1].child as TaskDetailsPage;
      expect(taskDetailsPage.taskId, taskId);
    });

    group('a document of a task -', () {
      final taskId = const Uuid().v4();
      final documentId = const Uuid().v4();

      BeamState stateFor(String path, Map<String, String> parameters) {
        final state = BeamState.fromRouteInformation(
          RouteInformation(uri: Uri.parse(path)),
        );
        return state.copyWith(
          pathParameters: {...state.pathParameters, ...parameters},
        );
      }

      test('on mobile stacks the document page over its task', () {
        final path = '/tasks/$taskId/documents/$documentId';
        final pages = TasksLocation(RouteInformation(uri: Uri.parse(path)))
            .buildPages(
              mockBuildContext,
              stateFor(path, {'taskId': taskId, 'documentId': documentId}),
            );

        expect(pages, hasLength(3));
        expect((pages[1].child as TaskDetailsPage).taskId, taskId);
        final page = pages[2].child as TaskDocumentPage;
        expect(page.taskId, taskId);
        expect(page.documentId, documentId);
      });

      testWidgets(
        'on desktop opens it over its task in the pane, and a URL naming '
        'only the task returns the pane to the task',
        (tester) async {
          await tester.pumpWidget(const SizedBox.shrink());
          when(() => mockNavService.isDesktopMode).thenReturn(true);
          when(
            () => mockNavService.resetDesktopTaskDetail(any()),
          ).thenAnswer((_) {});

          final path = '/tasks/$taskId/documents/$documentId';
          final pages = TasksLocation(RouteInformation(uri: Uri.parse(path)))
              .buildPages(
                mockBuildContext,
                stateFor(path, {'taskId': taskId, 'documentId': documentId}),
              );
          await tester.pump();

          expect(pages, hasLength(1));
          verify(() => mockNavService.resetDesktopTaskDetail(taskId)).called(1);
          expect(desktopDocument.value, (
            taskId: taskId,
            documentId: documentId,
          ));

          TasksLocation(
            RouteInformation(uri: Uri.parse('/tasks/$taskId')),
          ).buildPages(
            mockBuildContext,
            stateFor('/tasks/$taskId', {'taskId': taskId}),
          );
          await tester.pump();
          expect(desktopDocument.value, isNull);
        },
      );
    });

    testWidgets(
      'a demo-seeded task id opens the detail — on desktop it selects into '
      'the pane, on mobile it pushes the page',
      (tester) async {
        // Regression: the demo world used to seed readable slug ids
        // ('task-air-scrubbers'), which this location rejects via isUuid.
        // The route changed but nothing on screen did — reported as
        // "tapping a task does nothing at all".
        await tester.pumpWidget(const SizedBox.shrink());
        final taskId = demoAirScrubbersTaskId;
        final routeInformation = RouteInformation(
          uri: Uri.parse('/tasks/$taskId'),
        );
        final beamState = BeamState.fromRouteInformation(routeInformation);
        final state = beamState.copyWith(
          pathParameters: {...beamState.pathParameters, 'taskId': taskId},
        );

        when(() => mockNavService.isDesktopMode).thenReturn(false);
        final mobilePages = TasksLocation(
          routeInformation,
        ).buildPages(mockBuildContext, state);
        expect(mobilePages, hasLength(2));
        expect((mobilePages[1].child as TaskDetailsPage).taskId, taskId);

        when(() => mockNavService.isDesktopMode).thenReturn(true);
        when(
          () => mockNavService.resetDesktopTaskDetail(any()),
        ).thenAnswer((_) {});
        TasksLocation(routeInformation).buildPages(mockBuildContext, state);
        await tester.pump();
        verify(() => mockNavService.resetDesktopTaskDetail(taskId)).called(1);
      },
    );

    test(
      'in desktop mode, buildPages returns only root page '
      'and does not push detail page',
      () {
        final taskId = const Uuid().v4();

        when(() => mockNavService.isDesktopMode).thenReturn(true);
        when(
          () => mockNavService.resetDesktopTaskDetail(any()),
        ).thenAnswer((_) {});

        final routeInformation = RouteInformation(
          uri: Uri.parse('/tasks/$taskId'),
        );
        final location = TasksLocation(routeInformation);
        final beamState = BeamState.fromRouteInformation(routeInformation);
        final newBeamState = beamState.copyWith(
          pathParameters: {
            ...beamState.pathParameters,
            'taskId': taskId,
          },
        );

        final pages = location.buildPages(mockBuildContext, newBeamState);

        expect(pages.length, 1);
        expect(pages[0].child, isA<TasksRootPage>());
      },
    );

    testWidgets(
      'in desktop mode, buildPages resets the desktop task detail stack',
      (tester) async {
        await tester.pumpWidget(const SizedBox.shrink());
        final taskId = const Uuid().v4();

        when(() => mockNavService.isDesktopMode).thenReturn(true);
        when(
          () => mockNavService.resetDesktopTaskDetail(any()),
        ).thenAnswer((_) {});

        final routeInformation = RouteInformation(
          uri: Uri.parse('/tasks/$taskId'),
        );
        final location = TasksLocation(routeInformation);
        final beamState = BeamState.fromRouteInformation(routeInformation);
        final newBeamState = beamState.copyWith(
          pathParameters: {
            ...beamState.pathParameters,
            'taskId': taskId,
          },
        );

        location.buildPages(mockBuildContext, newBeamState);

        verifyNever(() => mockNavService.resetDesktopTaskDetail(any()));
        await tester.pump();

        verify(() => mockNavService.resetDesktopTaskDetail(taskId)).called(1);
      },
    );

    testWidgets(
      'in desktop mode without a task id, buildPages clears the stack',
      (tester) async {
        await tester.pumpWidget(const SizedBox.shrink());
        when(() => mockNavService.isDesktopMode).thenReturn(true);
        when(
          () => mockNavService.resetDesktopTaskDetail(any()),
        ).thenAnswer((_) {});

        final routeInformation = RouteInformation(uri: Uri.parse('/tasks'));
        final location = TasksLocation(routeInformation);
        final beamState = BeamState.fromRouteInformation(routeInformation);

        location.buildPages(mockBuildContext, beamState);

        verifyNever(() => mockNavService.resetDesktopTaskDetail(any()));
        await tester.pump();

        verify(() => mockNavService.resetDesktopTaskDetail(null)).called(1);
      },
    );
  });
}
