import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/pages/settings/health_import_page.dart';
import 'package:lotti/themes/themes_service.dart';

import '../../mocks/mocks.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockHealthImport = MockHealthImport();

  group('HealthImportPage Widget Tests - ', () {
    setUp(() {
      getIt
        ..registerSingleton<HealthImport>(mockHealthImport)
        ..registerSingleton<ThemesService>(ThemesService(watch: false));
    });
    tearDown(getIt.reset);

    testWidgets('page is displayed', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: const HealthImportPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Import Activity Data'), findsOneWidget);
    });
  });
}
