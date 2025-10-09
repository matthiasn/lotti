import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/ui/login/sync_login_modal_page.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('syncLoginModalPage returns a configured modal page',
      (tester) async {
    final pageIndexNotifier = ValueNotifier<int>(0);
    addTearDown(pageIndexNotifier.dispose);

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) {
            final page = syncLoginModalPage(
              context: context,
              pageIndexNotifier: pageIndexNotifier,
            );

            expect(page, isA<SliverWoltModalSheetPage>());
            expect(page.stickyActionBar, isNotNull);
            expect(page.topBarTitle, isNotNull);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });
}
