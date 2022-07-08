import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:lotti/widgets/charts/empty_dashboards_widget.dart';

import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EmptyDashboards Widget Tests - ', () {
    setUp(() {
      getIt.registerSingleton<ThemesService>(ThemesService(watch: false));
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
    });
  });
}
