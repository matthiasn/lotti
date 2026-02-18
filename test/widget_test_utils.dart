import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import 'mocks/mocks.dart';

/// Holds the mocks registered during [setUpTestGetIt] so tests can access
/// them for stubbing without re-creating or looking them up.
class TestGetItMocks {
  TestGetItMocks({
    required this.journalDb,
    required this.updateNotifications,
    required this.settingsDb,
    required this.loggingDb,
    required this.loggingService,
  });

  final MockJournalDb journalDb;
  final MockUpdateNotifications updateNotifications;
  final MockSettingsDb settingsDb;
  final MockLoggingDb loggingDb;
  final LoggingService loggingService;
}

/// Sets up GetIt with common mocks for widget tests.
///
/// Call this in setUp() before creating widgets that use controllers
/// which access GetIt (e.g., ChecklistController, ChecklistItemController,
/// ThemingController).
///
/// Pass additional services via [additionalSetup] to register extra mocks
/// after the core ones:
/// ```dart
/// final mocks = await setUpTestGetIt(
///   additionalSetup: () {
///     getIt.registerSingleton<EntitiesCacheService>(mockCache);
///   },
/// );
/// ```
Future<TestGetItMocks> setUpTestGetIt({
  void Function()? additionalSetup,
}) async {
  await getIt.reset();

  final mockUpdateNotifications = MockUpdateNotifications();
  final mockJournalDb = MockJournalDb();
  final mockSettingsDb = MockSettingsDb();
  final mockLoggingDb = MockLoggingDb();
  final loggingService = LoggingService();

  when(() => mockUpdateNotifications.updateStream)
      .thenAnswer((_) => const Stream.empty());
  when(() => mockJournalDb.journalEntityById(any()))
      .thenAnswer((_) async => null);
  when(() => mockSettingsDb.itemByKey(any())).thenAnswer((_) async => null);
  when(() => mockSettingsDb.saveSettingsItem(any(), any()))
      .thenAnswer((_) async => 1);

  getIt
    ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
    ..registerSingleton<JournalDb>(mockJournalDb)
    ..registerSingleton<SettingsDb>(mockSettingsDb)
    ..registerSingleton<LoggingDb>(mockLoggingDb)
    ..registerSingleton<LoggingService>(loggingService);

  additionalSetup?.call();

  return TestGetItMocks(
    journalDb: mockJournalDb,
    updateNotifications: mockUpdateNotifications,
    settingsDb: mockSettingsDb,
    loggingDb: mockLoggingDb,
    loggingService: loggingService,
  );
}

/// Tears down GetIt after tests.
/// Call this in tearDown() to clean up registrations.
Future<void> tearDownTestGetIt() async {
  await getIt.reset();
}

/// Ensures core services required by ThemingController are registered.
/// Unlike setUpTestGetIt, this does NOT reset GetIt - it only registers
/// missing services. Safe to call in tests that have their own setup.
void ensureThemingServicesRegistered() {
  if (!getIt.isRegistered<UpdateNotifications>()) {
    final mockUpdateNotifications = MockUpdateNotifications();
    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => const Stream.empty());
    getIt.registerSingleton<UpdateNotifications>(mockUpdateNotifications);
  }

  if (!getIt.isRegistered<SettingsDb>()) {
    final mockSettingsDb = MockSettingsDb();
    when(() => mockSettingsDb.itemByKey(any())).thenAnswer((_) async => null);
    when(() => mockSettingsDb.saveSettingsItem(any(), any()))
        .thenAnswer((_) async => 1);
    getIt.registerSingleton<SettingsDb>(mockSettingsDb);
  }

  if (!getIt.isRegistered<LoggingDb>()) {
    getIt.registerSingleton<LoggingDb>(MockLoggingDb());
  }

  if (!getIt.isRegistered<LoggingService>()) {
    getIt.registerSingleton<LoggingService>(LoggingService());
  }
}

const phoneMediaQueryData = MediaQueryData(
  size: Size(390, 844),
  padding: EdgeInsets.only(top: 47, bottom: 34),
);

Widget makeTestableWidget(
  Widget child, {
  MediaQueryData? mediaQueryData,
  List<Override> overrides = const [],
}) {
  final mq = mediaQueryData ?? phoneMediaQueryData;

  return ProviderScope(
    overrides: overrides,
    child: MediaQuery(
      data: mq,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          FormBuilderLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: SingleChildScrollView(child: child),
      ),
    ),
  );
}

Widget makeTestableWidget2(
  Widget child, {
  MediaQueryData? mediaQueryData,
}) {
  final mq = mediaQueryData ?? phoneMediaQueryData;

  return MediaQuery(
    data: mq,
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        FormBuilderLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

Widget makeTestableWidgetWithScaffold(
  Widget child, {
  List<Override> overrides = const [],
  ThemeData? theme,
  MediaQueryData? mediaQueryData,
}) {
  final mq = mediaQueryData ?? phoneMediaQueryData;

  return ProviderScope(
    overrides: overrides,
    child: MediaQuery(
      data: mq,
      child: MaterialApp(
        theme: theme,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          FormBuilderLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 800,
                maxWidth: 800,
              ),
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}

Widget makeTestableWidgetNoScroll(
  Widget child, {
  MediaQueryData? mediaQueryData,
}) {
  final mq = mediaQueryData ?? phoneMediaQueryData;

  return ProviderScope(
    child: MediaQuery(
      data: mq,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          FormBuilderLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    ),
  );
}
