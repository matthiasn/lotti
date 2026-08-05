import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/profiles/model/profile.dart';
import 'package:lotti/features/profiles/model/profile_context.dart';
import 'package:lotti/features/profiles/state/profile_providers.dart';
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

    testWidgets(
      'guest world never builds the child — even with the flag enabled',
      (tester) async {
        final mocks = await setUpTestGetIt();
        addTearDown(tearDownTestGetIt);

        // The flag says yes, but the capability says no: the child must
        // not build, because in guest worlds it would resolve providers
        // whose backing services are structurally absent.
        when(
          () => mocks.journalDb.watchConfigFlag(enableMatrixFlag),
        ).thenAnswer((_) => Stream.value(true));

        await tester.pumpWidget(
          makeTestableWidget(
            const SyncFeatureGate(
              child: Text('Sync Content'),
            ),
            overrides: [
              profileContextProvider.overrideWithValue(
                ProfileContext.forProfile(
                  profile: Profile(
                    id: 'demo-guest',
                    type: ProfileType.guest,
                    name: 'Demo',
                    dirName: 'guest_profiles/demo-guest',
                    createdAt: DateTime(2026),
                  ),
                  root: Directory.systemTemp,
                ),
              ),
            ],
          ),
        );

        await tester.pump();

        expect(find.text('Sync Content'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
