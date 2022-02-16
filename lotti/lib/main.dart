import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lotti/blocs/audio/player_cubit.dart';
import 'package:lotti/blocs/audio/recorder_cubit.dart';
import 'package:lotti/blocs/sync/outbox_cubit.dart';
import 'package:lotti/blocs/sync/sync_config_cubit.dart';
import 'package:lotti/database/insights_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/window_service.dart';
import 'package:lotti/utils/screenshots.dart';
import 'package:lotti/widgets/home.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isMacOS) {
    await windowManager.ensureInitialized();
    hotKeyManager.unregisterAll();
  }

  getIt.registerSingleton<WindowService>(WindowService());
  await getIt<WindowService>().restore();

  runZonedGuarded(() {
    registerSingletons();

    // FlutterError.onError = (FlutterErrorDetails details) {
    //   final InsightsDb _insightsDb = getIt<InsightsDb>();
    //   _insightsDb.captureException(details);
    // };

    initializeDateFormatting();
    registerScreenshotHotkey();

    runApp(const LottiApp());
  }, (Object error, StackTrace stackTrace) {
    final InsightsDb _insightsDb = getIt<InsightsDb>();
    _insightsDb.captureException(error, stackTrace: stackTrace);
  });
}

class LottiApp extends StatelessWidget {
  const LottiApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<SyncConfigCubit>(
          lazy: false,
          create: (BuildContext context) => SyncConfigCubit(),
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
      child: MaterialApp(
        title: 'Lotti',
        theme: ThemeData(
          primarySwatch: Colors.grey,
          primaryColorBrightness: Brightness.dark,
        ),
        home: const HomePage(),
        supportedLocales: const [
          Locale('en'),
        ],
        localizationsDelegates: const [FormBuilderLocalizations.delegate],
      ),
    );
  }
}
