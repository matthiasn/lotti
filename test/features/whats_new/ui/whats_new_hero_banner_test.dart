import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/whats_new/ui/whats_new_hero_banner.dart';

import '../../../widget_test_utils.dart';

Widget _banner({required bool isLatest}) {
  return Builder(
    builder: (context) => Localizations.override(
      context: context,
      locale: const Locale('de'),
      child: SizedBox(
        width: 320,
        height: 120,
        child: HeroBanner(
          imageUrl: null,
          version: '0.9.1049',
          isLatest: isLatest,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'localizes the latest-release badge and omits it for old releases',
    (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(_banner(isLatest: true)),
      );

      expect(find.text('NEU'), findsOneWidget);
      expect(find.text('v0.9.1049'), findsOneWidget);

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(_banner(isLatest: false)),
      );

      expect(find.text('NEU'), findsNothing);
      expect(find.text('v0.9.1049'), findsOneWidget);
    },
  );
}
