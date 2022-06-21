import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/sync/sync_config_cubit.dart';
import 'package:lotti/widgets/sync/imap_config_actions.dart';
import 'package:mocktail/mocktail.dart';

import '../../widget_test_utils.dart';
import '../sync_config_test_data.dart';
import '../sync_config_test_mocks.dart';

void main() {
  group('SyncConfig Imap Config Actions Widgets Tests - ', () {
    final mockRouter = MockStackRouter();

    setUp(() {
      reset(mockRouter);
      when(mockRouter.pop).thenAnswer((_) async => true);
    });

    testWidgets('Widget shows no button when status empty', (tester) async {
      final mock = mockSyncConfigCubitWithState(SyncConfigState.empty());

      await tester.pumpWidget(
        BlocProvider<SyncConfigCubit>(
          lazy: false,
          create: (BuildContext context) => mock,
          child: makeTestableWidget(
            ImapConfigActions(mockRouter: mockRouter),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final buttonFinder =
          find.byKey(const Key('settingsSyncDeleteImapButton'));
      expect(buttonFinder, findsNothing);
    });

    testWidgets('Widget shows delete button when status configured',
        (tester) async {
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
            ImapConfigActions(mockRouter: mockRouter),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final buttonFinder =
          find.byKey(const Key('settingsSyncDeleteImapButton'));
      expect(buttonFinder, findsOneWidget);

      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      verify(mockRouter.pop).called(1);
    });

    testWidgets('Widget shows save button when status valid', (tester) async {
      final mock = mockSyncConfigCubitWithState(
        SyncConfigState.imapValid(
          imapConfig: testImapConfig,
        ),
      );

      when(mock.saveImapConfig).thenAnswer((_) async {});

      await tester.pumpWidget(
        BlocProvider<SyncConfigCubit>(
          lazy: false,
          create: (BuildContext context) => mock,
          child: makeTestableWidget(
            ImapConfigActions(mockRouter: mockRouter),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final buttonFinder = find.byKey(const Key('settingsSyncSaveButton'));
      expect(buttonFinder, findsOneWidget);

      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();
    });

    testWidgets('Widget shows delete button when status saved', (tester) async {
      final mock = mockSyncConfigCubitWithState(
        SyncConfigState.imapSaved(
          imapConfig: testImapConfig,
        ),
      );

      when(mock.deleteImapConfig).thenAnswer((_) async {});

      await tester.pumpWidget(
        BlocProvider<SyncConfigCubit>(
          lazy: false,
          create: (BuildContext context) => mock,
          child: makeTestableWidget(
            ImapConfigActions(mockRouter: mockRouter),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final buttonFinder =
          find.byKey(const Key('settingsSyncDeleteImapButton'));
      expect(buttonFinder, findsOneWidget);

      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      verify(mockRouter.pop).called(1);
    });

    testWidgets('Widget shows delete button when status invalid',
        (tester) async {
      const testErrorMessage = 'testErrorMessage';
      final mock = mockSyncConfigCubitWithState(
        SyncConfigState.imapInvalid(
          imapConfig: testImapConfig,
          errorMessage: testErrorMessage,
        ),
      );

      when(mock.deleteImapConfig).thenAnswer((_) async {});

      await tester.pumpWidget(
        BlocProvider<SyncConfigCubit>(
          lazy: false,
          create: (BuildContext context) => mock,
          child: makeTestableWidget(
            ImapConfigActions(mockRouter: mockRouter),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final buttonFinder =
          find.byKey(const Key('settingsSyncDeleteImapButton'));
      expect(buttonFinder, findsOneWidget);

      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      verify(mockRouter.pop).called(1);
    });

    testWidgets('Widget shows delete button when status testing',
        (tester) async {
      final mock = mockSyncConfigCubitWithState(
        SyncConfigState.imapTesting(
          imapConfig: testImapConfig,
        ),
      );

      when(mock.deleteImapConfig).thenAnswer((_) async {});

      await tester.pumpWidget(
        BlocProvider<SyncConfigCubit>(
          lazy: false,
          create: (BuildContext context) => mock,
          child: makeTestableWidget(
            ImapConfigActions(mockRouter: mockRouter),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final buttonFinder =
          find.byKey(const Key('settingsSyncDeleteImapButton'));
      expect(buttonFinder, findsOneWidget);

      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      verify(mockRouter.pop).called(1);
    });
  });
}
