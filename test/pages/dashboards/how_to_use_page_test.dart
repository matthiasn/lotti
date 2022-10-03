import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/dashboards/how_to_use_page.dart';
import 'package:lotti/themes/themes_service.dart';

import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HowToUsePage Widget Tests - ', () {
    setUp(() {
      getIt.registerSingleton<ThemesService>(ThemesService(watch: false));
    });

    testWidgets('page is rendered with expected text ', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const HowToUsePage(),
        ),
      );

      await tester.pumpAndSettle();
      final buttonFinder = find.text('How to use Lotti');

      expect(buttonFinder, findsOneWidget);
    });
  });
}
