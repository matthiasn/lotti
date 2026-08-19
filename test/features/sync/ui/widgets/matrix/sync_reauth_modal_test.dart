import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/sync_reauth_modal.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  const password = Key('sync_reauth_password');
  const submit = Key('sync_reauth_submit');

  DesignSystemButton submitButton(WidgetTester tester) =>
      tester.widget<DesignSystemButton>(find.byKey(submit));

  Future<void> pumpForm(
    WidgetTester tester,
    Future<String?> Function(String password) onSubmit, {
    String deviceName = 'Lobby Kiosk',
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        SyncReauthForm(deviceName: deviceName, onSubmit: onSubmit),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('SyncReauthForm', () {
    testWidgets('names the device that is being removed', (tester) async {
      await pumpForm(tester, (_) async => null, deviceName: 'Mission Control');

      expect(
        find.textContaining('to remove Mission Control.'),
        findsOneWidget,
      );
    });

    testWidgets('cannot be submitted before a password is typed', (
      tester,
    ) async {
      var calls = 0;
      await pumpForm(tester, (_) async {
        calls++;
        return null;
      });

      expect(submitButton(tester).onPressed, isNull);

      await tester.enterText(find.byKey(password), 'hunter2');
      await tester.pump();

      expect(submitButton(tester).onPressed, isNotNull);
      expect(calls, 0);
    });

    testWidgets('hands the typed password to the retry', (tester) async {
      final submitted = <String>[];
      await pumpForm(tester, (value) async {
        submitted.add(value);
        return null;
      });

      await tester.enterText(find.byKey(password), 'rotated-secret');
      await tester.pump();
      await tester.tap(find.byKey(submit));
      await tester.pumpAndSettle();

      expect(submitted, ['rotated-secret']);
    });

    testWidgets('submits from the keyboard, so the field can be finished '
        'without reaching for the button', (tester) async {
      final submitted = <String>[];
      await pumpForm(tester, (value) async {
        submitted.add(value);
        return null;
      });

      await tester.enterText(find.byKey(password), 'rotated-secret');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(submitted, ['rotated-secret']);
    });

    testWidgets('keeps the sheet open and shows why, when the retry is '
        'refused', (tester) async {
      await pumpForm(tester, (_) async => 'That password did not work.');

      await tester.enterText(find.byKey(password), 'wrong');
      await tester.pump();
      await tester.tap(find.byKey(submit));
      await tester.pumpAndSettle();

      expect(find.text('That password did not work.'), findsOneWidget);
      // Still on the form: a typo costs one correction, not the whole flow.
      expect(find.byKey(password), findsOneWidget);
      expect(submitButton(tester).isLoading, isFalse);
    });

    testWidgets('retracts the rejection as soon as the password is edited', (
      tester,
    ) async {
      await pumpForm(tester, (_) async => 'That password did not work.');

      await tester.enterText(find.byKey(password), 'wrong');
      await tester.pump();
      await tester.tap(find.byKey(submit));
      await tester.pumpAndSettle();
      expect(find.text('That password did not work.'), findsOneWidget);

      await tester.enterText(find.byKey(password), 'wrong-but-edited');
      await tester.pump();

      expect(find.text('That password did not work.'), findsNothing);
    });

    testWidgets('shows the retry in flight and refuses to fire it twice', (
      tester,
    ) async {
      final gate = Completer<String?>();
      var calls = 0;
      await pumpForm(tester, (_) {
        calls++;
        return gate.future;
      });

      await tester.enterText(find.byKey(password), 'hunter2');
      await tester.pump();
      await tester.tap(find.byKey(submit));
      await tester.pump();

      expect(submitButton(tester).isLoading, isTrue);

      await tester.tap(find.byKey(submit));
      await tester.pump();
      expect(calls, 1);

      gate.complete('Still refused.');
      await tester.pumpAndSettle();
      expect(find.text('Still refused.'), findsOneWidget);
      expect(calls, 1);
    });
  });

  group('showSyncReauthModal', () {
    Future<void> pumpOpener(
      WidgetTester tester,
      Future<String?> Function(String password) onSubmit, {
      required void Function({required bool removed}) record,
    }) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final result = await showSyncReauthModal(
                  context: context,
                  deviceName: 'Lobby Kiosk',
                  onSubmit: onSubmit,
                );
                record(removed: result);
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('resolves true once the retry is accepted', (tester) async {
      bool? outcome;
      await pumpOpener(
        tester,
        (_) async => null,
        record: ({required removed}) => outcome = removed,
      );

      await tester.enterText(find.byKey(password), 'rotated');
      await tester.pump();
      await tester.tap(find.byKey(submit));
      await tester.pumpAndSettle();

      expect(outcome, isTrue);
      expect(find.byKey(password), findsNothing);
    });

    testWidgets('resolves false when the user backs out', (tester) async {
      bool? outcome;
      var calls = 0;
      await pumpOpener(
        tester,
        (_) async {
          calls++;
          return null;
        },
        record: ({required removed}) => outcome = removed,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(outcome, isFalse);
      expect(calls, 0);
    });

    testWidgets('resolves false when the sheet is dismissed without an '
        'answer', (tester) async {
      bool? outcome;
      await pumpOpener(
        tester,
        (_) async => null,
        record: ({required removed}) => outcome = removed,
      );

      // The Wolt close affordance pops without a result — the caller must read
      // that as "not removed" rather than inheriting a null-shaped success.
      await tester.tap(find.byIcon(LottiIcons.close));
      await tester.pumpAndSettle();

      expect(outcome, isFalse);
    });
  });
}
