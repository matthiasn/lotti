import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/widgets/journal/entry_details/share_button_widget.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider/path_provider.dart';

import '../../../helpers/path_provider.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

void main() {
  group('ShareButtonWidget', () {
    setUpAll(() async {
      setFakeDocumentsPath();

      final mockUpdateNotifications = MockUpdateNotifications();
      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<({DatabaseType type, String id})>.fromIterable([]),
      );

      getIt
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<Directory>(await getApplicationDocumentsDirectory())
        ..registerSingleton<JournalDb>(JournalDb(inMemoryDatabase: true))
        ..registerSingleton<TagsService>(TagsService());
    });

    testWidgets('tap share icon on image', (WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ShareButtonWidget(entryId: testImageEntry.meta.id),
        ),
      );
      await tester.pumpAndSettle();
      final shareIconFinder = find.byIcon(MdiIcons.shareOutline);
      expect(shareIconFinder, findsOneWidget);

      await tester.tap(shareIconFinder);
      await tester.pumpAndSettle();
    });

    testWidgets('tap share icon on audio', (WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ShareButtonWidget(entryId: testAudioEntry.meta.id),
        ),
      );
      await tester.pumpAndSettle();
      final shareIconFinder = find.byIcon(MdiIcons.shareOutline);
      expect(shareIconFinder, findsOneWidget);

      await tester.tap(shareIconFinder);
      await tester.pumpAndSettle();
    });
  });
}
