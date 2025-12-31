import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import 'mocks/mocks.dart';

/// Sets up GetIt with common mocks for widget tests.
/// Call this in setUp() before creating widgets that use controllers
/// which access GetIt (e.g., ChecklistController, ChecklistItemController).
Future<void> setUpTestGetIt() async {
  await getIt.reset();

  final mockUpdateNotifications = MockUpdateNotifications();
  final mockJournalDb = MockJournalDb();

  when(() => mockUpdateNotifications.updateStream)
      .thenAnswer((_) => const Stream.empty());
  when(() => mockJournalDb.journalEntityById(any()))
      .thenAnswer((_) async => null);

  getIt
    ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
    ..registerSingleton<JournalDb>(mockJournalDb);
}

/// Tears down GetIt after tests.
/// Call this in tearDown() to clean up registrations.
Future<void> tearDownTestGetIt() async {
  await getIt.reset();
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
