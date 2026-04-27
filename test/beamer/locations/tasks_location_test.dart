import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/locations/tasks_location.dart';
import 'package:lotti/features/tasks/ui/pages/task_details_page.dart';
import 'package:lotti/features/tasks/ui/pages/tasks_root_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';

import '../../mocks/mocks.dart';

class MockBuildContext extends Mock implements BuildContext {}

void main() {
  group('TasksLocation', () {
    late MockBuildContext mockBuildContext;

    late MockNavService mockNavService;

    setUp(() {
      mockBuildContext = MockBuildContext();
      mockNavService = MockNavService();
      when(() => mockNavService.isDesktopMode).thenReturn(false);
      getIt
        ..allowReassignment = true
        ..registerSingleton<NavService>(mockNavService);
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
      expect(location.pathPatterns, ['/tasks', '/tasks/:taskId']);
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

    test(
      'in desktop mode, buildPages resets the desktop task detail stack',
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

        location.buildPages(mockBuildContext, newBeamState);

        verify(() => mockNavService.resetDesktopTaskDetail(taskId)).called(1);
      },
    );

    test(
      'in desktop mode without a task id, buildPages clears the stack',
      () {
        when(() => mockNavService.isDesktopMode).thenReturn(true);
        when(
          () => mockNavService.resetDesktopTaskDetail(any()),
        ).thenAnswer((_) {});

        final routeInformation = RouteInformation(uri: Uri.parse('/tasks'));
        final location = TasksLocation(routeInformation);
        final beamState = BeamState.fromRouteInformation(routeInformation);

        location.buildPages(mockBuildContext, beamState);

        verify(() => mockNavService.resetDesktopTaskDetail(null)).called(1);
      },
    );
  });
}
