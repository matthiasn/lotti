import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:lotti/blocs/audio/player_cubit.dart';
import 'package:lotti/blocs/audio/recorder_cubit.dart';
import 'package:lotti/blocs/sync/outbox_cubit.dart';
import 'package:lotti/blocs/sync/sync_config_cubit.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/routes/router.gr.dart';
import 'package:lotti/services/window_service.dart';
import 'package:lotti/sync/secure_storage.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/utils/screenshots.dart';
import 'package:lotti/widgets/misc/desktop_menu.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isMacOS) {
    await windowManager.ensureInitialized();
    await hotKeyManager.unregisterAll();
  }

  getIt
    ..registerSingleton<SecureStorage>(SecureStorage())
    ..registerSingleton<WindowService>(WindowService());

  await getIt<WindowService>().restore();
  tz.initializeTimeZones();

  runZonedGuarded(() {
    registerSingletons();

    FlutterError.onError = (FlutterErrorDetails details) {
      getIt<LoggingDb>().captureException(
        details,
        domain: 'MAIN',
        subDomain: 'onError',
      );
    };

    registerScreenshotHotkey();

    runApp(LottiApp());
  }, (Object error, StackTrace stackTrace) {
    getIt<LoggingDb>().captureException(
      error,
      domain: 'MAIN',
      subDomain: 'runZonedGuarded',
      stackTrace: stackTrace,
    );
  });
}

class LottiApp extends StatelessWidget {
  LottiApp({super.key});
  final router = getIt<AppRouter>();

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<SyncConfigCubit>(
          lazy: false,
          create: (BuildContext context) => SyncConfigCubit(
            testOnNetworkChange: true,
          ),
        ),
        BlocProvider<OutboxCubit>(
          lazy: false,
          create: (BuildContext context) => OutboxCubit(),
        ),
        BlocProvider<AudioRecorderCubit>(
          create: (BuildContext context) => AudioRecorderCubit(),
        ),
        BlocProvider<AudioPlayerCubit>(
          create: (BuildContext context) => AudioPlayerCubit(),
        ),
      ],
      child: StreamBuilder<Themes>(
        stream: getIt<ThemeService>().getStream(),
        builder: (context, snapshot) {
          return DesktopMenuWrapper(
            key: Key('theme-${snapshot.data}'),
            MaterialApp.router(
              localizationsDelegates: const [
                AppLocalizations.delegate,
                FormBuilderLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              theme: ThemeData(
                primarySwatch: Colors.grey,
              ),
              debugShowCheckedModeBanner: false,
              routerDelegate: router.delegate(
                navigatorObservers: () => [],
              ),
              routeInformationParser: router.defaultRouteParser(),
            ),
          );
        },
      ),
    );
  }
}
