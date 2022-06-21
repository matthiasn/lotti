import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/sync/sync_config_cubit.dart';
import 'package:lotti/widgets/sync/imap_config_form.dart';
import 'package:lotti/widgets/sync/imap_config_utils.dart';
import 'package:mocktail/mocktail.dart';

import '../../widget_test_utils.dart';
import '../sync_config_test_data.dart';
import '../sync_config_test_mocks.dart';

void main() {
  group('SyncConfig QR Widget Tests - ', () {
    testWidgets('Widget shows form status empty', (tester) async {
      final mock = mockSyncConfigCubitWithState(SyncConfigState.empty());
      final formKey = GlobalKey<FormBuilderState>();

      await tester.pumpWidget(
        BlocProvider<SyncConfigCubit>(
          lazy: false,
          create: (BuildContext context) => mock,
          child: makeTestableWidget(
            Material(
              child: ImapConfigForm(
                formKey: formKey,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final hostFieldFinder = find.byKey(const Key('imap_host_form_field'));
      final userFieldFinder =
          find.byKey(const Key('imap_user_name_form_field'));
      final passwordFieldFinder =
          find.byKey(const Key('imap_password_form_field'));
      final portFieldFinder = find.byKey(const Key('imap_port_form_field'));

      expect(hostFieldFinder, findsOneWidget);
      expect(userFieldFinder, findsOneWidget);
      expect(passwordFieldFinder, findsOneWidget);
      expect(portFieldFinder, findsOneWidget);

      expect(formKey.currentState!.isValid, isFalse);
    });

    testWidgets('Widget shows filled form when status IMAP saved',
        (tester) async {
      final mock = mockSyncConfigCubitWithState(
        SyncConfigState.imapSaved(imapConfig: testImapConfig),
      );
      final formKey = GlobalKey<FormBuilderState>();

      await tester.pumpWidget(
        BlocProvider<SyncConfigCubit>(
          lazy: false,
          create: (BuildContext context) => mock,
          child: makeTestableWidget(
            Material(
              child: ImapConfigForm(
                formKey: formKey,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final hostFieldFinder = find.byKey(const Key('imap_host_form_field'));
      final userFieldFinder =
          find.byKey(const Key('imap_user_name_form_field'));
      final passwordFieldFinder =
          find.byKey(const Key('imap_password_form_field'));
      final portFieldFinder = find.byKey(const Key('imap_port_form_field'));

      expect(hostFieldFinder, findsOneWidget);
      expect(userFieldFinder, findsOneWidget);
      expect(passwordFieldFinder, findsOneWidget);
      expect(portFieldFinder, findsOneWidget);

      final passwordInput =
          tester.widget<FormBuilderTextField>(passwordFieldFinder);

      expect(passwordInput.obscureText, true);
      expect(formKey.currentState!.isValid, isTrue);

      formKey.currentState?.save();
      final formData = formKey.currentState!.value;

      expect(getTrimmed(formData, 'imap_host'), testImapConfig.host);
      expect(getTrimmed(formData, 'imap_userName'), testImapConfig.userName);
      expect(getPort(formData), testImapConfig.port);
      expect(getTrimmed(formData, 'imap_password'), testImapConfig.password);
    });

    testWidgets('Widget shows filled form when status IMAP invalid',
        (tester) async {
      final mock = mockSyncConfigCubitWithState(
        SyncConfigState.imapInvalid(
          imapConfig: testImapConfig,
          errorMessage: 'Error',
        ),
      );
      final formKey = GlobalKey<FormBuilderState>();

      await tester.pumpWidget(
        BlocProvider<SyncConfigCubit>(
          lazy: false,
          create: (BuildContext context) => mock,
          child: makeTestableWidget(
            Material(
              child: ImapConfigForm(
                formKey: formKey,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final hostFieldFinder = find.byKey(const Key('imap_host_form_field'));
      final userFieldFinder =
          find.byKey(const Key('imap_user_name_form_field'));
      final passwordFieldFinder =
          find.byKey(const Key('imap_password_form_field'));
      final portFieldFinder = find.byKey(const Key('imap_port_form_field'));

      expect(hostFieldFinder, findsOneWidget);
      expect(userFieldFinder, findsOneWidget);
      expect(passwordFieldFinder, findsOneWidget);
      expect(portFieldFinder, findsOneWidget);

      final passwordInput =
          tester.widget<FormBuilderTextField>(passwordFieldFinder);

      expect(passwordInput.obscureText, true);
      expect(formKey.currentState!.isValid, isTrue);

      formKey.currentState?.save();
      final formData = formKey.currentState!.value;

      expect(getTrimmed(formData, 'imap_host'), testImapConfig.host);
      expect(getTrimmed(formData, 'imap_userName'), testImapConfig.userName);
      expect(getPort(formData), testImapConfig.port);
      expect(getTrimmed(formData, 'imap_password'), testImapConfig.password);
    });

    testWidgets('Widget shows filled form when status IMAP valid',
        (tester) async {
      final mock = mockSyncConfigCubitWithState(
        SyncConfigState.imapValid(imapConfig: testImapConfig),
      );
      final formKey = GlobalKey<FormBuilderState>();

      await tester.pumpWidget(
        BlocProvider<SyncConfigCubit>(
          lazy: false,
          create: (BuildContext context) => mock,
          child: makeTestableWidget(
            Material(
              child: ImapConfigForm(
                formKey: formKey,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final hostFieldFinder = find.byKey(const Key('imap_host_form_field'));
      final userFieldFinder =
          find.byKey(const Key('imap_user_name_form_field'));
      final passwordFieldFinder =
          find.byKey(const Key('imap_password_form_field'));
      final portFieldFinder = find.byKey(const Key('imap_port_form_field'));

      expect(hostFieldFinder, findsOneWidget);
      expect(userFieldFinder, findsOneWidget);
      expect(passwordFieldFinder, findsOneWidget);
      expect(portFieldFinder, findsOneWidget);

      final passwordInput =
          tester.widget<FormBuilderTextField>(passwordFieldFinder);

      expect(passwordInput.obscureText, true);
      expect(formKey.currentState!.isValid, isTrue);

      formKey.currentState?.save();
      final formData = formKey.currentState!.value;

      expect(getTrimmed(formData, 'imap_host'), testImapConfig.host);
      expect(getTrimmed(formData, 'imap_userName'), testImapConfig.userName);
      expect(getPort(formData), testImapConfig.port);
      expect(getTrimmed(formData, 'imap_password'), testImapConfig.password);
    });

    testWidgets('Widget shows filled form when status IMAP testing',
        (tester) async {
      final mock = mockSyncConfigCubitWithState(
        SyncConfigState.imapTesting(imapConfig: testImapConfig),
      );
      final formKey = GlobalKey<FormBuilderState>();

      await tester.pumpWidget(
        BlocProvider<SyncConfigCubit>(
          lazy: false,
          create: (BuildContext context) => mock,
          child: makeTestableWidget(
            Material(
              child: ImapConfigForm(
                formKey: formKey,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final hostFieldFinder = find.byKey(const Key('imap_host_form_field'));
      final userFieldFinder =
          find.byKey(const Key('imap_user_name_form_field'));
      final passwordFieldFinder =
          find.byKey(const Key('imap_password_form_field'));
      final portFieldFinder = find.byKey(const Key('imap_port_form_field'));

      expect(hostFieldFinder, findsOneWidget);
      expect(userFieldFinder, findsOneWidget);
      expect(passwordFieldFinder, findsOneWidget);
      expect(portFieldFinder, findsOneWidget);

      final passwordInput =
          tester.widget<FormBuilderTextField>(passwordFieldFinder);

      expect(passwordInput.obscureText, true);
      expect(formKey.currentState!.isValid, isTrue);

      formKey.currentState?.save();
      final formData = formKey.currentState!.value;

      expect(getTrimmed(formData, 'imap_host'), testImapConfig.host);
      expect(getTrimmed(formData, 'imap_userName'), testImapConfig.userName);
      expect(getPort(formData), testImapConfig.port);
      expect(getTrimmed(formData, 'imap_password'), testImapConfig.password);
    });

    testWidgets('Widget shows filled form when status IMAP configured',
        (tester) async {
      final mock = mockSyncConfigCubitWithState(
        SyncConfigState.generating(),
      );
      final formKey = GlobalKey<FormBuilderState>();

      await tester.pumpWidget(
        BlocProvider<SyncConfigCubit>(
          lazy: false,
          create: (BuildContext context) => mock,
          child: makeTestableWidget(
            Material(
              child: ImapConfigForm(
                formKey: formKey,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final hostFieldFinder = find.byKey(const Key('imap_host_form_field'));
      final userFieldFinder =
          find.byKey(const Key('imap_user_name_form_field'));
      final passwordFieldFinder =
          find.byKey(const Key('imap_password_form_field'));
      final portFieldFinder = find.byKey(const Key('imap_port_form_field'));

      expect(hostFieldFinder, findsOneWidget);
      expect(userFieldFinder, findsOneWidget);
      expect(passwordFieldFinder, findsOneWidget);
      expect(portFieldFinder, findsOneWidget);

      final passwordInput =
          tester.widget<FormBuilderTextField>(passwordFieldFinder);

      expect(passwordInput.obscureText, true);
      expect(formKey.currentState!.isValid, isFalse);
    });

    testWidgets('Widget shows filled form when status loading', (tester) async {
      final mock = mockSyncConfigCubitWithState(
        SyncConfigState.loading(),
      );
      final formKey = GlobalKey<FormBuilderState>();

      await tester.pumpWidget(
        BlocProvider<SyncConfigCubit>(
          lazy: false,
          create: (BuildContext context) => mock,
          child: makeTestableWidget(
            Material(
              child: ImapConfigForm(
                formKey: formKey,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final hostFieldFinder = find.byKey(const Key('imap_host_form_field'));
      final userFieldFinder =
          find.byKey(const Key('imap_user_name_form_field'));
      final passwordFieldFinder =
          find.byKey(const Key('imap_password_form_field'));
      final portFieldFinder = find.byKey(const Key('imap_port_form_field'));

      expect(hostFieldFinder, findsNothing);
      expect(userFieldFinder, findsNothing);
      expect(passwordFieldFinder, findsNothing);
      expect(portFieldFinder, findsNothing);

      expect(formKey.currentState, isNull);
    });

    testWidgets('Widget shows filled form when status IMAP configured',
        (tester) async {
      final mock = mockSyncConfigCubitWithState(
        SyncConfigState.configured(
          imapConfig: testImapConfig,
          sharedSecret: testSharedKey,
        ),
      );
      final formKey = GlobalKey<FormBuilderState>();

      await tester.pumpWidget(
        BlocProvider<SyncConfigCubit>(
          lazy: false,
          create: (BuildContext context) => mock,
          child: makeTestableWidget(
            Material(
              child: ImapConfigForm(
                formKey: formKey,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final hostFieldFinder = find.byKey(const Key('imap_host_form_field'));
      final userFieldFinder =
          find.byKey(const Key('imap_user_name_form_field'));
      final passwordFieldFinder =
          find.byKey(const Key('imap_password_form_field'));
      final portFieldFinder = find.byKey(const Key('imap_port_form_field'));

      expect(hostFieldFinder, findsOneWidget);
      expect(userFieldFinder, findsOneWidget);
      expect(passwordFieldFinder, findsOneWidget);
      expect(portFieldFinder, findsOneWidget);

      final passwordInput =
          tester.widget<FormBuilderTextField>(passwordFieldFinder);

      expect(passwordInput.obscureText, true);

      expect(formKey.currentState!.isValid, isTrue);

      formKey.currentState?.save();
      final formData = formKey.currentState!.value;

      expect(getTrimmed(formData, 'imap_host'), testImapConfig.host);
      expect(getTrimmed(formData, 'imap_userName'), testImapConfig.userName);
      expect(getPort(formData), testImapConfig.port);
      expect(getTrimmed(formData, 'imap_password'), testImapConfig.password);
    });

    testWidgets('Widget shows form when status empty, then filled',
        (tester) async {
      final mock = mockSyncConfigCubitWithState(SyncConfigState.empty());
      final formKey = GlobalKey<FormBuilderState>();

      when(() => mock.setImapConfig(any())).thenAnswer((_) async => true);

      await tester.pumpWidget(
        BlocProvider<SyncConfigCubit>(
          lazy: false,
          create: (BuildContext context) => mock,
          child: makeTestableWidget(
            Material(
              child: ImapConfigForm(
                formKey: formKey,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final hostFieldFinder = find.byKey(const Key('imap_host_form_field'));
      final userFieldFinder =
          find.byKey(const Key('imap_user_name_form_field'));
      final passwordFieldFinder =
          find.byKey(const Key('imap_password_form_field'));
      final portFieldFinder = find.byKey(const Key('imap_port_form_field'));

      expect(hostFieldFinder, findsOneWidget);
      expect(userFieldFinder, findsOneWidget);
      expect(passwordFieldFinder, findsOneWidget);
      expect(portFieldFinder, findsOneWidget);

      expect(formKey.currentState!.isValid, isFalse);

      await tester.enterText(hostFieldFinder, 'hostname');
      await tester.enterText(userFieldFinder, 'userName');
      await tester.enterText(passwordFieldFinder, 'password');
      await tester.enterText(portFieldFinder, '111');

      final formData = formKey.currentState!.value;
      expect(getTrimmed(formData, 'imap_host'), 'hostname');
      expect(getTrimmed(formData, 'imap_userName'), 'userName');
      expect(getPort(formData), 111);
      expect(getTrimmed(formData, 'imap_password'), 'password');
    });
  });
}
