import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lotti/blocs/audio/player_cubit.dart';
import 'package:lotti/blocs/audio/recorder_cubit.dart';
import 'package:lotti/blocs/journal/health_cubit.dart';
import 'package:lotti/blocs/journal/journal_image_cubit.dart';
import 'package:lotti/blocs/journal/persistence_cubit.dart';
import 'package:lotti/blocs/sync/imap/inbox_cubit.dart';
import 'package:lotti/blocs/sync/imap/outbox_cubit.dart';
import 'package:lotti/blocs/sync/outbox_cubit.dart';
import 'package:lotti/blocs/sync/sync_config_cubit.dart';
import 'package:lotti/database/insights_db.dart';
import 'package:lotti/services/sync_config_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/widgets/home.dart';
import 'package:window_manager/window_manager.dart';

import 'database/database.dart';
import 'database/sync_db.dart';

final getIt = GetIt.instance;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  runZonedGuarded(() {
    getIt.registerSingleton<JournalDb>(JournalDb());
    getIt.registerSingleton<TagsService>(TagsService());
    getIt<JournalDb>().initConfigFlags();
    getIt.registerSingleton<SyncDatabase>(SyncDatabase());
    getIt.registerSingleton<InsightsDb>(InsightsDb());
    getIt.registerSingleton<VectorClockService>(VectorClockService());
    getIt.registerSingleton<SyncConfigService>(SyncConfigService());
    getIt.registerSingleton<TimeService>(TimeService());

    initializeDateFormatting();

    FlutterError.onError = (FlutterErrorDetails details) {
      final InsightsDb _insightsDb = getIt<InsightsDb>();
      _insightsDb.captureException(details);
    };

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
        BlocProvider<OutboxImapCubit>(
          lazy: false,
          create: (BuildContext context) => OutboxImapCubit(),
        ),
        BlocProvider<OutboxCubit>(
          lazy: false,
          create: (BuildContext context) => OutboxCubit(
            outboxImapCubit: BlocProvider.of<OutboxImapCubit>(context),
          ),
        ),
        BlocProvider<PersistenceCubit>(
          lazy: false,
          create: (BuildContext context) => PersistenceCubit(
            outboundQueueCubit: BlocProvider.of<OutboxCubit>(context),
          ),
        ),
        BlocProvider<InboxImapCubit>(
          lazy: false,
          create: (BuildContext context) => InboxImapCubit(
            persistenceCubit: BlocProvider.of<PersistenceCubit>(context),
          ),
        ),
        BlocProvider<HealthCubit>(
          lazy: true,
          create: (BuildContext context) => HealthCubit(
            persistenceCubit: BlocProvider.of<PersistenceCubit>(context),
          ),
        ),
        BlocProvider<JournalImageCubit>(
          lazy: false,
          create: (BuildContext context) => JournalImageCubit(
            persistenceCubit: BlocProvider.of<PersistenceCubit>(context),
          ),
        ),
        BlocProvider<AudioRecorderCubit>(
          create: (BuildContext context) => AudioRecorderCubit(
            persistenceCubit: BlocProvider.of<PersistenceCubit>(context),
          ),
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
