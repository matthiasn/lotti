import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/sync/sync_config_cubit.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme/theme.dart';
import 'package:lotti/widgets/sync/imap_config_status.dart';

import '../../widget_test_utils.dart';
import '../sync_config_test_data.dart';
import '../sync_config_test_mocks.dart';

void main() {
  group('SyncConfig Imap Config Status Widgets Tests - ', () {
    testWidgets(
        'Widget shows grey status indicator & correct label when status empty',
        (tester) async {
      final mock = mockSyncConfigCubitWithState(SyncConfigState.empty());

      await tester.pumpWidget(
        BlocProvider<SyncConfigCubit>(
          lazy: false,
          create: (BuildContext context) => mock,
          child: makeTestableWidget(const ImapConfigStatus()),
        ),
      );

      await tester.pumpAndSettle();

      final labelFinder = find.text('Please enter valid account details.');
      expect(labelFinder, findsOneWidget);

      final successIndicatorFinder = find.byContainerColor(color: Colors.grey);
      expect(successIndicatorFinder, findsOneWidget);
    });

    testWidgets(
        'Widget shows grey status indicator & correct label when status loading',
        (tester) async {
      final mock = mockSyncConfigCubitWithState(SyncConfigState.loading());

      await tester.pumpWidget(
        BlocProvider<SyncConfigCubit>(
          lazy: false,
          create: (BuildContext context) => mock,
          child: makeTestableWidget(const ImapConfigStatus()),
        ),
      );

      await tester.pumpAndSettle();

      final labelFinder = find.text('Loading...');
      expect(labelFinder, findsOneWidget);

      final successIndicatorFinder = find.byContainerColor(color: Colors.grey);
      expect(successIndicatorFinder, findsOneWidget);
    });

    testWidgets(
        'Widget shows grey status indicator & correct label when status generating',
        (tester) async {
      final mock = mockSyncConfigCubitWithState(SyncConfigState.generating());

      await tester.pumpWidget(
        BlocProvider<SyncConfigCubit>(
          lazy: false,
          create: (BuildContext context) => mock,
          child: makeTestableWidget(const ImapConfigStatus()),
        ),
      );

      await tester.pumpAndSettle();

      final labelFinder = find.text('Generating secret...');
      expect(labelFinder, findsOneWidget);

      final successIndicatorFinder = find.byContainerColor(color: Colors.grey);
      expect(successIndicatorFinder, findsOneWidget);
    });

    testWidgets(
        'Widget shows green status indicator & correct label when status configured',
        (tester) async {
      final mock = mockSyncConfigCubitWithState(
        SyncConfigState.configured(
          imapConfig: testImapConfig,
          sharedSecret: testSharedKey,
        ),
      );

      await tester.pumpWidget(
        BlocProvider<SyncConfigCubit>(
          lazy: false,
          create: (BuildContext context) => mock,
          child: makeTestableWidget(const ImapConfigStatus()),
        ),
      );

      await tester.pumpAndSettle();

      final labelFinder = find.text('Account is successfully configured.');
      expect(labelFinder, findsOneWidget);

      final successIndicatorFinder = find.byContainerColor(
        color: getIt<ThemeService>().colors.outboxSuccessColor,
      );

      expect(successIndicatorFinder, findsOneWidget);
    });

    testWidgets(
        'Widget shows green status indicator & correct label when status valid',
        (tester) async {
      final mock = mockSyncConfigCubitWithState(
        SyncConfigState.imapValid(
          imapConfig: testImapConfig,
        ),
      );

      await tester.pumpWidget(
        BlocProvider<SyncConfigCubit>(
          lazy: false,
          create: (BuildContext context) => mock,
          child: makeTestableWidget(const ImapConfigStatus()),
        ),
      );

      await tester.pumpAndSettle();

      final labelFinder = find.text('Account is valid.');
      expect(labelFinder, findsOneWidget);

      final successIndicatorFinder = find.byContainerColor(
        color: getIt<ThemeService>().colors.outboxSuccessColor,
      );

      expect(successIndicatorFinder, findsOneWidget);
    });

    testWidgets(
        'Widget shows green status indicator & correct label when status saved',
        (tester) async {
      final mock = mockSyncConfigCubitWithState(
        SyncConfigState.imapSaved(
          imapConfig: testImapConfig,
        ),
      );

      await tester.pumpWidget(
        BlocProvider<SyncConfigCubit>(
          lazy: false,
          create: (BuildContext context) => mock,
          child: makeTestableWidget(const ImapConfigStatus()),
        ),
      );

      await tester.pumpAndSettle();

      final labelFinder = find.text('IMAP configuration saved.');
      expect(labelFinder, findsOneWidget);

      final successIndicatorFinder = find.byContainerColor(
        color: getIt<ThemeService>().colors.outboxSuccessColor,
      );

      expect(successIndicatorFinder, findsOneWidget);
    });

    testWidgets(
        'Widget shows green status indicator & correct label when status invalid',
        (tester) async {
      const testErrorMessage = 'testErrorMessage';
      final mock = mockSyncConfigCubitWithState(
        SyncConfigState.imapInvalid(
          imapConfig: testImapConfig,
          errorMessage: testErrorMessage,
        ),
      );

      await tester.pumpWidget(
        BlocProvider<SyncConfigCubit>(
          lazy: false,
          create: (BuildContext context) => mock,
          child: makeTestableWidget(const ImapConfigStatus()),
        ),
      );

      await tester.pumpAndSettle();

      final labelFinder = find.text(testErrorMessage);
      expect(labelFinder, findsOneWidget);

      final successIndicatorFinder =
          find.byContainerColor(color: getIt<ThemeService>().colors.error);

      expect(successIndicatorFinder, findsOneWidget);
    });

    testWidgets(
        'Widget shows green status indicator & correct label when status testing',
        (tester) async {
      final mock = mockSyncConfigCubitWithState(
        SyncConfigState.imapTesting(
          imapConfig: testImapConfig,
        ),
      );

      await tester.pumpWidget(
        BlocProvider<SyncConfigCubit>(
          lazy: false,
          create: (BuildContext context) => mock,
          child: makeTestableWidget(const ImapConfigStatus()),
        ),
      );

      await tester.pumpAndSettle();

      final labelFinder = find.text('Testing IMAP connection...');
      expect(labelFinder, findsOneWidget);

      final successIndicatorFinder = find.byContainerColor(
        color: getIt<ThemeService>().colors.outboxPendingColor,
      );

      expect(successIndicatorFinder, findsOneWidget);
    });
  });
}
