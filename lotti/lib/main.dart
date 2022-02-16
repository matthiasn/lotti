import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:get_it/get_it.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lotti/blocs/audio/player_cubit.dart';
import 'package:lotti/blocs/audio/recorder_cubit.dart';
import 'package:lotti/blocs/sync/outbox_cubit.dart';
import 'package:lotti/blocs/sync/sync_config_cubit.dart';
import 'package:lotti/database/insights_db.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/sync_config_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/services/window_service.dart';
import 'package:lotti/sync/inbox_service.dart';
import 'package:lotti/sync/outbox.dart';
import 'package:lotti/utils/screenshots.dart';
import 'package:lotti/widgets/home.dart';
import 'package:window_manager/window_manager.dart';

import 'database/database.dart';
import 'database/sync_db.dart';
import 'logic/health_import.dart';
import 'logic/persistence_logic.dart';

final getIt = GetIt.instance;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isMacOS) {
    await windowManager.ensureInitialized();
    hotKeyManager.unregisterAll();
  }

  runZonedGuarded(() {
    getIt.registerSingleton<WindowService>(WindowService());
    getIt.registerSingleton<JournalDb>(JournalDb());
    getIt.registerSingleton<TagsService>(TagsService());
    getIt<JournalDb>().initConfigFlags();
    getIt.registerSingleton<SyncDatabase>(SyncDatabase());
    getIt.registerSingleton<InsightsDb>(InsightsDb());
    getIt.registerSingleton<VectorClockService>(VectorClockService());
    getIt.registerSingleton<SyncConfigService>(SyncConfigService());
    getIt.registerSingleton<TimeService>(TimeService());
    getIt.registerSingleton<OutboxService>(OutboxService());
    getIt.registerSingleton<PersistenceLogic>(PersistenceLogic());
    getIt.registerSingleton<HealthImport>(HealthImport());
    getIt.registerSingleton<SyncInboxService>(SyncInboxService());
    getIt.registerSingleton<LinkService>(LinkService());
    getIt.registerSingleton<NotificationService>(NotificationService());

    initializeDateFormatting();

    FlutterError.onError = (FlutterErrorDetails details) {
      final InsightsDb _insightsDb = getIt<InsightsDb>();
      _insightsDb.captureException(details);
    };

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
