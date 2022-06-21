import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/sync/sync_config_cubit.dart';
import 'package:lotti/widgets/sync/qr_widget.dart';
import 'package:mocktail/mocktail.dart';

import '../../widget_test_utils.dart';
import '../sync_config_test_data.dart';
import '../sync_config_test_mocks.dart';

void main() {
  group('SyncConfig QR Widget Tests - ', () {
    testWidgets('Widget shows no button when status empty', (tester) async {
      final mock = mockSyncConfigCubitWithState(SyncConfigState.empty());

      await tester.pumpWidget(
        BlocProvider<SyncConfigCubit>(
          lazy: false,
          create: (BuildContext context) => mock,
          child: makeTestableWidget(const EncryptionQrWidget()),
        ),
      );

      await tester.pumpAndSettle();

      final buttonFinder =
          find.byKey(const Key('settingsSyncDeleteImapButton'));
      expect(buttonFinder, findsNothing);
    });

    testWidgets('Widget shows no button when status loading', (tester) async {
      final mock = mockSyncConfigCubitWithState(SyncConfigState.loading());

      await tester.pumpWidget(
        BlocProvider<SyncConfigCubit>(
          lazy: false,
          create: (BuildContext context) => mock,
          child: makeTestableWidget(const EncryptionQrWidget()),
        ),
      );

      await tester.pumpAndSettle();

      final buttonFinder =
          find.byKey(const Key('settingsSyncDeleteImapButton'));
      expect(buttonFinder, findsNothing);
    });

    testWidgets('Widget shows generate button when status ImapValid',
        (tester) async {
      final mock = mockSyncConfigCubitWithState(
        SyncConfigState.imapValid(
          imapConfig: testImapConfig,
        ),
      );

      when(mock.generateSharedKey).thenAnswer((invocation) async {});

      await tester.pumpWidget(
        BlocProvider<SyncConfigCubit>(
          lazy: false,
          create: (BuildContext context) => mock,
          child: makeTestableWidget(const EncryptionQrWidget()),
        ),
      );

      await tester.pumpAndSettle();

      final buttonFinder = find.byKey(const Key('genKeyButton'));
      expect(buttonFinder, findsOneWidget);

      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      verify(mock.generateSharedKey).called(1);
    });

    testWidgets('Widget shows no button when status generating',
        (tester) async {
      final mock = mockSyncConfigCubitWithState(SyncConfigState.generating());

      await tester.pumpWidget(
        BlocProvider<SyncConfigCubit>(
          lazy: false,
          create: (BuildContext context) => mock,
          child: makeTestableWidget(const EncryptionQrWidget()),
        ),
      );

      await tester.pumpAndSettle();

      final buttonFinder = find.byElementType(ElevatedButton);
      expect(buttonFinder, findsNothing);

      final labelFinder = find.text('Generating shared key...');
      expect(labelFinder, findsOneWidget);
    });

    testWidgets(
        'Widget shows QR code and delete button when status configured, '
        'then allows interaction', (tester) async {
      final mock = mockSyncConfigCubitWithState(
        SyncConfigState.configured(
          imapConfig: testImapConfig,
          sharedSecret: testSharedKey,
        ),
      );

      when(mock.deleteImapConfig).thenAnswer((_) async {});

      await tester.pumpWidget(
        BlocProvider<SyncConfigCubit>(
          lazy: false,
          create: (BuildContext context) => mock,
          child: makeTestableWidget(
            const EncryptionQrWidget(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final buttonFinder = find.byKey(const Key('deleteSyncKeyButton'));
      expect(buttonFinder, findsOneWidget);

      final qrFinder = find.byKey(const Key('QrImage'));
      expect(qrFinder, findsOneWidget);

      final clickableQrFinder = find.byKey(const Key('QrImageGestureDetector'));
      expect(clickableQrFinder, findsOneWidget);

      final cancelButtonFinder = find.byKey(const Key('cancelCopyButton'));
      final copyButtonFinder = find.byKey(const Key('copyButton'));
      expect(cancelButtonFinder, findsNothing);
      expect(copyButtonFinder, findsNothing);

      // Tapping QR code opens copy dialog
      await tester.tap(qrFinder);
      await tester.pumpAndSettle();

      final copySyncAlertHeadlineFinder =
          find.text('Copy SyncConfig to Clipboard?');
      expect(copySyncAlertHeadlineFinder, findsOneWidget);

      expect(cancelButtonFinder, findsOneWidget);
      expect(copyButtonFinder, findsOneWidget);

      // Tapping cancel closes copy dialog
      await tester.tap(cancelButtonFinder);
      await tester.pumpAndSettle();

      expect(cancelButtonFinder, findsNothing);
      expect(copyButtonFinder, findsNothing);

      // Tapping QR code opens copy dialog (again)
      await tester.tap(qrFinder);
      await tester.pumpAndSettle();

      // Tapping Copy button closes copy dialog
      await tester.tap(copyButtonFinder);
      await tester.pumpAndSettle();

      expect(cancelButtonFinder, findsNothing);
      expect(copyButtonFinder, findsNothing);
    });

    testWidgets(
        'Widget shows paste button when status configured, '
        'then allows interaction', (tester) async {
      final mock = mockSyncConfigCubitWithState(SyncConfigState.empty());

      when(mock.deleteImapConfig).thenAnswer((_) async {});

      await tester.pumpWidget(
        BlocProvider<SyncConfigCubit>(
          lazy: false,
          create: (BuildContext context) => mock,
          child: makeTestableWidget(
            const EncryptionQrWidget(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final pasteButtonFinder = find.byKey(const Key('settingsSyncPasteCfg'));
      expect(pasteButtonFinder, findsOneWidget);

      final cancelButtonFinder = find.byKey(const Key('syncCancelButton'));
      expect(cancelButtonFinder, findsNothing);

      await tester.tap(pasteButtonFinder);
      await tester.pumpAndSettle();

      expect(cancelButtonFinder, findsOneWidget);

      await tester.tap(cancelButtonFinder);
      await tester.pumpAndSettle();

      expect(cancelButtonFinder, findsNothing);
      expect(pasteButtonFinder, findsOneWidget);

      await tester.tap(pasteButtonFinder);
      await tester.pumpAndSettle();

      final importButtonFinder = find.byKey(const Key('syncImportButton'));
      expect(importButtonFinder, findsOneWidget);

      await tester.tap(importButtonFinder);
      await tester.pumpAndSettle();
    });
  });
}
