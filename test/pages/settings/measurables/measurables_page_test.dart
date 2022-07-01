import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/settings/measurables/measurables_page.dart';
import 'package:lotti/themes/themes_service.dart';

import '../../../test_data.dart';
import '../../../widget_test_utils.dart';
import '../mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();

  group('MeasurablesPage Widget Tests - ', () {
    setUp(() {
      mockJournalDb = mockJournalDbWithMeasurableTypes([
        measurableWater,
        measurableChocolate,
      ]);

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<ColorsService>(ColorsService(watch: false));
    });
    tearDown(getIt.reset);

    testWidgets('measurables page is displayed', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: const MeasurablesPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text(measurableWater.displayName), findsOneWidget);
      expect(find.text(measurableWater.description), findsOneWidget);
      expect(find.text(measurableChocolate.displayName), findsOneWidget);
      expect(find.text(measurableChocolate.description), findsOneWidget);
    });
  });
}
