import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/ui/widgets/task_detail_back_leading.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/app_bar/glass_back_button.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  late MockNavService mockNavService;
  late ValueNotifier<List<String>> stack;

  setUp(() async {
    mockNavService = MockNavService();
    stack = ValueNotifier<List<String>>(const <String>[]);
    when(() => mockNavService.desktopTaskDetailStack).thenReturn(stack);

    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<NavService>(mockNavService);
      },
    );
  });

  tearDown(() async {
    stack.dispose();
    await tearDownTestGetIt();
  });

  Future<void> pumpLeading(WidgetTester tester) => tester.pumpWidget(
    makeTestableWidgetWithScaffold(const TaskDetailDesktopBackLeading()),
  );

  group('TaskDetailDesktopBackLeading', () {
    testWidgets('hides the button while at most one task is stacked', (
      tester,
    ) async {
      await pumpLeading(tester);
      expect(find.byType(GlassBackButton), findsNothing);

      stack.value = const ['base-task'];
      await tester.pump();
      expect(find.byType(GlassBackButton), findsNothing);
    });

    testWidgets('shows the button for a layered linked task and pops on tap', (
      tester,
    ) async {
      stack.value = const ['base-task', 'linked-task'];
      await pumpLeading(tester);

      expect(find.byType(GlassBackButton), findsOneWidget);

      await tester.tap(find.byType(GlassBackButton));
      verify(() => mockNavService.popDesktopTaskDetail()).called(1);
    });

    testWidgets('reacts to stack pushes and pops', (tester) async {
      stack.value = const ['base-task'];
      await pumpLeading(tester);
      expect(find.byType(GlassBackButton), findsNothing);

      // A linked task gets layered on top — the back affordance appears.
      stack.value = const ['base-task', 'linked-task'];
      await tester.pump();
      expect(find.byType(GlassBackButton), findsOneWidget);

      // Back at the base task — the arrow disappears again.
      stack.value = const ['base-task'];
      await tester.pump();
      expect(find.byType(GlassBackButton), findsNothing);
    });
  });
}
