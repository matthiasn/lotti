import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:lotti/widgets/charts/empty_dashboards_widget.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final mockJournalDb = MockJournalDb();
  when(mockJournalDb.watchDashboards)
      .thenAnswer((_) => Stream<List<DashboardDefinition>>.fromIterable([[]]));

  group('EmptyDashboards Widget Tests - ', () {
    setUp(() {
      getIt
        ..registerSingleton<ThemesService>(ThemesService(watch: false))
        ..registerSingleton<JournalDb>(mockJournalDb);
    });
    tearDown(getIt.reset);

    testWidgets(
        'page with link to manual is rendered when no dashboards defined',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const EmptyDashboards(),
        ),
      );

      await tester.pump();

      expect(
        find.text('Check out the manual for more information'),
        findsOneWidget,
      );
      verify(mockJournalDb.watchDashboards).called(1);
    });
  });
}
