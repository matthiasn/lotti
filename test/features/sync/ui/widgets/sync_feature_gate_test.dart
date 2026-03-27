import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/ui/widgets/sync_feature_gate.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('SyncFeatureGate', () {
    testWidgets('renders child when flag is enabled', (tester) async {
      final mocks = await setUpTestGetIt();
      addTearDown(tearDownTestGetIt);

      when(
        () => mocks.journalDb.watchConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) => Stream.value(true));

      await tester.pumpWidget(
        makeTestableWidget(
          const SyncFeatureGate(
            child: Text('Sync Content'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Sync Content'), findsOneWidget);
    });

    testWidgets('renders nothing while loading', (tester) async {
      final mocks = await setUpTestGetIt();
      addTearDown(tearDownTestGetIt);

      // Stream that never emits
      final controller = StreamController<bool>();
      addTearDown(controller.close);

      when(
        () => mocks.journalDb.watchConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) => controller.stream);

      await tester.pumpWidget(
        makeTestableWidget(
          const SyncFeatureGate(
            child: Text('Sync Content'),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Sync Content'), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('renders SizedBox.shrink when flag is disabled', (
      tester,
    ) async {
      final mocks = await setUpTestGetIt();
      addTearDown(tearDownTestGetIt);

      when(
        () => mocks.journalDb.watchConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) => Stream.value(false));

      await tester.pumpWidget(
        makeTestableWidget(
          const SyncFeatureGate(
            child: Text('Sync Content'),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Sync Content'), findsNothing);
    });
  });
}
