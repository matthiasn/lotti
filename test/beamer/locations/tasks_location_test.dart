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
      getIt.allowReassignment = true;
      getIt.registerSingleton<NavService>(mockNavService);
    });

    tearDown(() {
      if (getIt.isRegistered<NavService>()) {
        getIt.unregister<NavService>();
      }
      getIt.allowReassignment = false;
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
  });
}
