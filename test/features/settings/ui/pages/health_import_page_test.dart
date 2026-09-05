import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/callouts/design_system_inline_callout.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/profiles/model/profile.dart';
import 'package:lotti/features/profiles/model/profile_context.dart';
import 'package:lotti/features/profiles/state/profile_providers.dart';
import 'package:lotti/features/settings/state/health_import_controller.dart';
import 'package:lotti/features/settings/ui/pages/health_import_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/utils/platform.dart' as platform;
import 'package:lotti/widgets/date_time/datetime_field.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart'
    show PermissionHandlerPlatform;

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

/// Fake [PermissionHandlerPlatform] recording whether the page handed off to
/// the operating system's settings.
class _RecordingPermissionHandler extends PermissionHandlerPlatform {
  int openAppSettingsCalls = 0;

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCalls++;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHealthImport mockHealthImport;

  setUp(() async {
    // The page ships on iOS/Android only; the macOS test host would otherwise
    // take the "unavailable" branch for every test.
    final originalIsDesktop = platform.isDesktop;
    final originalIsMobile = platform.isMobile;
    platform.isDesktop = false;
    platform.isMobile = true;
    addTearDown(() {
      platform.isDesktop = originalIsDesktop;
      platform.isMobile = originalIsMobile;
    });

    mockHealthImport = MockHealthImport();
    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<HealthImport>(mockHealthImport)
          ..registerSingleton<UserActivityService>(UserActivityService());
      },
    );
  });

  tearDown(tearDownTestGetIt);

  void stubImports(HealthImportResult result) {
    when(
      () => mockHealthImport.getActivityHealthData(
        dateFrom: any(named: 'dateFrom'),
        dateTo: any(named: 'dateTo'),
      ),
    ).thenAnswer((_) async => result);
    when(
      () => mockHealthImport.getWorkoutsHealthData(
        dateFrom: any(named: 'dateFrom'),
        dateTo: any(named: 'dateTo'),
      ),
    ).thenAnswer((_) async => result);
    when(
      () => mockHealthImport.fetchHealthData(
        types: any(named: 'types'),
        dateFrom: any(named: 'dateFrom'),
        dateTo: any(named: 'dateTo'),
      ),
    ).thenAnswer((_) async => result);
  }

  /// Pumps the page in a viewport tall enough to hold the whole surface, so
  /// every row and the footer button are laid out *and* hit-testable without
  /// scrolling mid-assertion.
  Future<void> pumpPage(WidgetTester tester) async {
    const size = Size(600, 1600);
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const HealthImportPage(),
        mediaQueryData: const MediaQueryData(size: size),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Returns the `setDateTime` callback of the [DateTimeField] labelled
  /// [labelText]. Driving it exercises the page's range handlers without
  /// fighting the Cupertino picker wheels.
  void Function(DateTime) setDateTimeFor(
    WidgetTester tester,
    String labelText,
  ) => tester
      .widget<DateTimeField>(
        find.byWidgetPredicate(
          (w) => w is DateTimeField && w.labelText == labelText,
        ),
      )
      .setDateTime;

  /// The row for [title], as the list item that renders it.
  DesignSystemListItem rowFor(WidgetTester tester, String title) =>
      tester.widget<DesignSystemListItem>(
        find.ancestor(
          of: find.text(title),
          matching: find.byType(DesignSystemListItem),
        ),
      );

  Future<void> tapRow(WidgetTester tester, String title) async {
    final finder = find.text(title);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
  }

  group('layout', () {
    testWidgets('renders one row per data family, in enum order', (
      tester,
    ) async {
      stubImports(const HealthImportResult.imported(0));
      await pumpPage(tester);

      const expectedTitles = [
        'Activity',
        'Sleep',
        'Heart Rate',
        'Blood Pressure',
        'Body Measurements',
        'Workouts',
      ];

      expect(expectedTitles.length, HealthImportCategory.values.length);
      for (final title in expectedTitles) {
        expect(find.text(title), findsOneWidget, reason: 'missing $title');
      }

      // Rendered top-to-bottom in the same order the enum declares.
      final renderedOrder = tester
          .widgetList<DesignSystemListItem>(
            find.byType(DesignSystemListItem),
          )
          .map((item) => item.title)
          .toList();
      expect(renderedOrder, expectedTitles);
    });

    testWidgets('each row describes what it will import before any run', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(
        rowFor(tester, 'Activity').subtitle,
        'Steps, flights climbed and walking distance',
      );
      expect(rowFor(tester, 'Sleep').subtitle, 'Time in bed and sleep stages');
      expect(
        rowFor(tester, 'Workouts').subtitle,
        'Workouts with distance and energy burned',
      );
    });

    testWidgets('the last row carries no divider beneath it', (tester) async {
      await pumpPage(tester);

      expect(rowFor(tester, 'Activity').showDivider, isTrue);
      expect(rowFor(tester, 'Workouts').showDivider, isFalse);
    });

    testWidgets('hides the unavailable callout on mobile', (tester) async {
      await pumpPage(tester);

      expect(find.byType(DesignSystemInlineCallout), findsNothing);
    });

    testWidgets('warns instead of pretending to work on desktop', (
      tester,
    ) async {
      // Both flags, so the state is one a real desktop target can be in —
      // `isDesktop` is derived from `!isMobile` in production.
      platform.isDesktop = true;
      platform.isMobile = false;
      await pumpPage(tester);

      expect(find.byType(DesignSystemInlineCallout), findsOneWidget);
      expect(
        find.text('Health data is only available on iOS and Android'),
        findsOneWidget,
      );
    });
  });

  // The escape hatch for the reported bug: a data type switched off in
  // Settings → Privacy & Security → Health cannot be re-prompted by HealthKit,
  // so the page has to point the user at the only place that can fix it.
  group('the access callout', () {
    const hint =
        'Some data could not be read. If you turned Lotti’s access off in '
        'your device’s health privacy settings, Lotti cannot ask for it again '
        '— turn it back on there.';

    Finder openSettingsButton() => find.widgetWithText(
      DesignSystemButton,
      'Open settings',
    );

    testWidgets('is absent before anything has run', (tester) async {
      stubImports(const HealthImportResult.imported(0));
      await pumpPage(tester);

      expect(find.text(hint), findsNothing);
      expect(openSettingsButton(), findsNothing);
    });

    testWidgets('is absent after an ordinary empty import', (tester) async {
      stubImports(const HealthImportResult.imported(0));
      await pumpPage(tester);

      await tapRow(tester, 'Blood Pressure');
      await tester.pumpAndSettle();

      expect(openSettingsButton(), findsNothing);
    });

    testWidgets('appears when a run suspects an access problem', (
      tester,
    ) async {
      stubImports(const HealthImportResult.noDataOrAccess());
      await pumpPage(tester);

      await tapRow(tester, 'Blood Pressure');
      await tester.pumpAndSettle();

      expect(find.text(hint), findsOneWidget);
      expect(openSettingsButton(), findsOneWidget);
    });

    testWidgets('appears when a run was refused outright', (tester) async {
      stubImports(const HealthImportResult.permissionDenied());
      await pumpPage(tester);

      await tapRow(tester, 'Blood Pressure');
      await tester.pumpAndSettle();

      expect(openSettingsButton(), findsOneWidget);
    });

    testWidgets('is absent after an unrelated failure', (tester) async {
      // A health store that threw is not something the privacy settings fix;
      // sending the user there would be a wrong lead.
      stubImports(HealthImportResult.failed(Exception('kaboom')));
      await pumpPage(tester);

      await tapRow(tester, 'Blood Pressure');
      await tester.pumpAndSettle();

      expect(openSettingsButton(), findsNothing);
    });

    testWidgets('goes away once the range moves on', (tester) async {
      stubImports(const HealthImportResult.noDataOrAccess());
      await pumpPage(tester);

      await tapRow(tester, 'Blood Pressure');
      await tester.pumpAndSettle();
      expect(openSettingsButton(), findsOneWidget);

      setDateTimeFor(tester, 'Start')(DateTime(2020));
      await tester.pumpAndSettle();

      expect(openSettingsButton(), findsNothing);
    });

    testWidgets('hands off to the operating system when pressed', (
      tester,
    ) async {
      final originalPlatform = PermissionHandlerPlatform.instance;
      final permissionHandler = _RecordingPermissionHandler();
      PermissionHandlerPlatform.instance = permissionHandler;
      addTearDown(() => PermissionHandlerPlatform.instance = originalPlatform);

      stubImports(const HealthImportResult.noDataOrAccess());
      await pumpPage(tester);

      await tapRow(tester, 'Blood Pressure');
      await tester.pumpAndSettle();

      await tester.ensureVisible(openSettingsButton());
      await tester.pumpAndSettle();
      await tester.tap(openSettingsButton());
      await tester.pumpAndSettle();

      expect(permissionHandler.openAppSettingsCalls, 1);
    });

    testWidgets('a suspected access problem reads as a warning, not an error', (
      tester,
    ) async {
      stubImports(const HealthImportResult.noDataOrAccess());
      await pumpPage(tester);

      await tapRow(tester, 'Blood Pressure');
      await tester.pumpAndSettle();

      expect(
        rowFor(tester, 'Blood Pressure').subtitle,
        'No data — check Lotti’s access in your health app',
      );
      expect(find.byIcon(LottiIcons.lock), findsOneWidget);
    });
  });

  group('date range', () {
    testWidgets('both date fields render the controller range', (tester) async {
      await pumpPage(tester);

      final fields = tester
          .widgetList<DateTimeField>(find.byType(DateTimeField))
          .toList();
      expect(fields, hasLength(2));
      expect(fields.first.labelText, 'Start');
      expect(fields.last.labelText, 'End');
      expect(
        fields.first.dateTime!.isBefore(fields.last.dateTime!),
        isTrue,
      );
    });

    testWidgets('setting the start date updates the field and the import', (
      tester,
    ) async {
      stubImports(const HealthImportResult.imported(0));
      await pumpPage(tester);

      expect(find.text('2024-03-15'), findsNothing);
      setDateTimeFor(tester, 'Start')(DateTime(2024, 3, 15));
      await tester.pumpAndSettle();
      expect(find.text('2024-03-15'), findsOneWidget);

      await tapRow(tester, 'Activity');
      await tester.pumpAndSettle();

      verify(
        () => mockHealthImport.getActivityHealthData(
          dateFrom: DateTime(2024, 3, 15),
          dateTo: any(named: 'dateTo'),
        ),
      ).called(1);
    });

    testWidgets('setting the end date updates the field and the import', (
      tester,
    ) async {
      stubImports(const HealthImportResult.imported(0));
      await pumpPage(tester);

      setDateTimeFor(tester, 'Start')(DateTime(2024, 3));
      await tester.pumpAndSettle();
      setDateTimeFor(tester, 'End')(DateTime(2024, 3, 20));
      await tester.pumpAndSettle();
      expect(find.text('2024-03-20'), findsOneWidget);

      await tapRow(tester, 'Activity');
      await tester.pumpAndSettle();

      verify(
        () => mockHealthImport.getActivityHealthData(
          dateFrom: DateTime(2024, 3),
          dateTo: DateTime(2024, 3, 20, 23, 59, 59, 999),
        ),
      ).called(1);
    });

    testWidgets('changing the range clears a rendered result', (tester) async {
      stubImports(const HealthImportResult.imported(42));
      await pumpPage(tester);

      await tapRow(tester, 'Sleep');
      await tester.pumpAndSettle();
      expect(rowFor(tester, 'Sleep').subtitle, '42 samples imported');

      setDateTimeFor(tester, 'Start')(DateTime(2024, 3, 15));
      await tester.pumpAndSettle();

      // Back to describing what the row *will* import, not what a different
      // range once did.
      expect(
        rowFor(tester, 'Sleep').subtitle,
        'Time in bed and sleep stages',
      );
    });

    testWidgets('a quick range rewrites both dates', (tester) async {
      await pumpPage(tester);

      final before = tester
          .widgetList<DateTimeField>(find.byType(DateTimeField))
          .first
          .dateTime!;

      await tester.tap(find.text('Last 90 days'));
      await tester.pumpAndSettle();

      final after = tester
          .widgetList<DateTimeField>(find.byType(DateTimeField))
          .first
          .dateTime!;

      expect(after.isBefore(before), isTrue);
      expect(
        tester
            .widgetList<DateTimeField>(find.byType(DateTimeField))
            .last
            .dateTime!
            .difference(after)
            .inDays,
        90,
      );
    });

    testWidgets('all three quick ranges are offered', (tester) async {
      await pumpPage(tester);

      for (final days in healthImportQuickRangeDays) {
        expect(find.text('Last $days days'), findsOneWidget);
      }
    });
  });

  group('running an import', () {
    testWidgets('a row shows a spinner while its import is in flight', (
      tester,
    ) async {
      final gate = Completer<HealthImportResult>();
      when(
        () => mockHealthImport.fetchHealthData(
          types: any(named: 'types'),
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
        ),
      ).thenAnswer((_) => gate.future);

      await pumpPage(tester);
      await tapRow(tester, 'Heart Rate');
      await tester.pump();

      expect(find.byType(DesignSystemSpinner), findsOneWidget);
      expect(rowFor(tester, 'Heart Rate').subtitle, 'Importing…');
      // A running row cannot be tapped again.
      expect(rowFor(tester, 'Heart Rate').onTap, isNull);

      gate.complete(const HealthImportResult.imported(1));
      await tester.pumpAndSettle();
      expect(find.byType(DesignSystemSpinner), findsNothing);
    });

    testWidgets('every row goes inert while any import is in flight', (
      tester,
    ) async {
      // The controller refuses overlapping runs, so an enabled row would
      // promise something the tap could not deliver.
      final gate = Completer<HealthImportResult>();
      when(
        () => mockHealthImport.getActivityHealthData(
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
        ),
      ).thenAnswer((_) => gate.future);

      await pumpPage(tester);
      expect(rowFor(tester, 'Sleep').onTap, isNotNull);

      await tapRow(tester, 'Activity');
      await tester.pump();

      for (final title in ['Activity', 'Sleep', 'Workouts']) {
        expect(
          rowFor(tester, title).onTap,
          isNull,
          reason: '$title should be inert while Activity imports',
        );
      }

      gate.complete(const HealthImportResult.imported(1));
      stubImports(const HealthImportResult.imported(1));
      await tester.pumpAndSettle();

      expect(rowFor(tester, 'Sleep').onTap, isNotNull);
    });

    testWidgets('a finished import reports its sample count on the row', (
      tester,
    ) async {
      stubImports(const HealthImportResult.imported(42));
      await pumpPage(tester);

      await tapRow(tester, 'Blood Pressure');
      await tester.pumpAndSettle();

      expect(rowFor(tester, 'Blood Pressure').subtitle, '42 samples imported');
      verify(
        () => mockHealthImport.fetchHealthData(
          types: bpTypes,
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
        ),
      ).called(1);
    });

    testWidgets('an empty import reads as "no new samples", not an error', (
      tester,
    ) async {
      stubImports(const HealthImportResult.imported(0));
      await pumpPage(tester);

      await tapRow(tester, 'Sleep');
      await tester.pumpAndSettle();

      expect(rowFor(tester, 'Sleep').subtitle, 'No new samples');
      expect(find.byIcon(LottiIcons.confirmCircled), findsOneWidget);
    });

    testWidgets('a refused authorization tells the user what to do', (
      tester,
    ) async {
      stubImports(const HealthImportResult.permissionDenied());
      await pumpPage(tester);

      await tapRow(tester, 'Heart Rate');
      await tester.pumpAndSettle();

      expect(
        rowFor(tester, 'Heart Rate').subtitle,
        'Access denied — allow Lotti in your health app',
      );
      // A padlock, not an error cross: nothing malfunctioned, and the glyph
      // should point at where this is fixed rather than alarm about it.
      expect(find.byIcon(LottiIcons.lock), findsOneWidget);
    });

    testWidgets('a failure is surfaced rather than swallowed', (tester) async {
      // The old page fired imports without awaiting them, so a failure and a
      // success looked identical: nothing happened either way.
      stubImports(HealthImportResult.failed(Exception('kaboom')));
      await pumpPage(tester);

      await tapRow(tester, 'Workouts');
      await tester.pumpAndSettle();

      expect(
        rowFor(tester, 'Workouts').subtitle,
        'Import failed — check the logs',
      );
      expect(find.byIcon(LottiIcons.error), findsOneWidget);
    });

    testWidgets('only the tapped row changes', (tester) async {
      stubImports(const HealthImportResult.imported(7));
      await pumpPage(tester);

      await tapRow(tester, 'Sleep');
      await tester.pumpAndSettle();

      expect(rowFor(tester, 'Sleep').subtitle, '7 samples imported');
      expect(
        rowFor(tester, 'Heart Rate').subtitle,
        'Resting rate, walking rate and variability',
      );
    });

    testWidgets('every row delegates to its own importer', (tester) async {
      stubImports(const HealthImportResult.imported(1));
      await pumpPage(tester);

      for (final title in [
        'Sleep',
        'Heart Rate',
        'Blood Pressure',
        'Body Measurements',
      ]) {
        await tapRow(tester, title);
        await tester.pumpAndSettle();
      }
      await tapRow(tester, 'Activity');
      await tester.pumpAndSettle();
      await tapRow(tester, 'Workouts');
      await tester.pumpAndSettle();

      for (final types in [
        sleepTypes,
        heartRateTypes,
        bpTypes,
        bodyMeasurementTypes,
      ]) {
        verify(
          () => mockHealthImport.fetchHealthData(
            types: types,
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
          ),
        ).called(1);
      }
      verify(
        () => mockHealthImport.getActivityHealthData(
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
        ),
      ).called(1);
      verify(
        () => mockHealthImport.getWorkoutsHealthData(
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
        ),
      ).called(1);
    });
  });

  group('import all', () {
    testWidgets('runs every category and reports each one', (tester) async {
      stubImports(const HealthImportResult.imported(3));
      await pumpPage(tester);

      final button = find.widgetWithText(DesignSystemButton, 'Import all');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();

      for (final title in [
        'Activity',
        'Sleep',
        'Heart Rate',
        'Blood Pressure',
        'Body Measurements',
        'Workouts',
      ]) {
        expect(
          rowFor(tester, title).subtitle,
          '3 samples imported',
          reason: '$title was not run by "Import all"',
        );
      }
    });

    testWidgets('the button shows its loading state while work is in flight', (
      tester,
    ) async {
      final gate = Completer<HealthImportResult>();
      when(
        () => mockHealthImport.getActivityHealthData(
          dateFrom: any(named: 'dateFrom'),
          dateTo: any(named: 'dateTo'),
        ),
      ).thenAnswer((_) => gate.future);

      await pumpPage(tester);

      DesignSystemButton importAll() => tester.widget<DesignSystemButton>(
        find.widgetWithText(DesignSystemButton, 'Import all'),
      );

      expect(importAll().isLoading, isFalse);

      final button = find.widgetWithText(DesignSystemButton, 'Import all');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pump();

      expect(importAll().isLoading, isTrue);

      gate.complete(const HealthImportResult.imported(0));
      stubImports(const HealthImportResult.imported(0));
      await tester.pumpAndSettle();

      expect(importAll().isLoading, isFalse);
    });
  });

  group('pure presentation helpers', () {
    late AppLocalizations messages;
    const tokens = dsTokensDark;

    setUp(() async {
      messages = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('every category has a distinct icon, title and description', () {
      final icons = <IconData>{};
      final titles = <String>{};
      final descriptions = <String>{};

      for (final category in HealthImportCategory.values) {
        icons.add(healthImportCategoryIcon(category));
        titles.add(healthImportCategoryTitle(messages, category));
        descriptions.add(healthImportCategoryDescription(messages, category));
      }

      expect(icons, hasLength(HealthImportCategory.values.length));
      expect(titles, hasLength(HealthImportCategory.values.length));
      expect(descriptions, hasLength(HealthImportCategory.values.length));
    });

    test('every outcome has a label and none of them is blank', () {
      final labels = {
        for (final result in <HealthImportResult>[
          const HealthImportResult.imported(1),
          const HealthImportResult.permissionDenied(),
          const HealthImportResult.noDataOrAccess(),
          const HealthImportResult.unsupportedPlatform(),
          const HealthImportResult.noMatchingTypes(),
          HealthImportResult.failed(Exception('x')),
        ])
          result.status: healthImportResultLabel(messages, result),
      };

      expect(labels.keys, containsAll(HealthImportStatus.values));
      for (final label in labels.values) {
        expect(label, isNotEmpty);
      }
    });

    test('the sample count is pluralized, including the zero case', () {
      expect(
        healthImportResultLabel(messages, const HealthImportResult.imported(0)),
        'No new samples',
      );
      expect(
        healthImportResultLabel(messages, const HealthImportResult.imported(1)),
        '1 sample imported',
      );
      expect(
        healthImportResultLabel(messages, const HealthImportResult.imported(2)),
        '2 samples imported',
      );
    });

    test('tones separate success, a refusal, and a genuine failure', () {
      final success = healthImportResultTone(
        tokens,
        const HealthImportResult.imported(1),
      );
      final denied = healthImportResultTone(
        tokens,
        const HealthImportResult.permissionDenied(),
      );
      final failed = healthImportResultTone(
        tokens,
        HealthImportResult.failed(Exception('x')),
      );

      expect(success, tokens.colors.alert.success.defaultColor);
      expect(denied, tokens.colors.alert.warning.defaultColor);
      expect(failed, tokens.colors.alert.error.defaultColor);
      expect({success, denied, failed}, hasLength(3));
    });

    test('an unavailable platform is a warning, not an error', () {
      // Nothing is broken on desktop — there is simply no health store.
      expect(
        healthImportResultTone(
          tokens,
          const HealthImportResult.unsupportedPlatform(),
        ),
        tokens.colors.alert.warning.defaultColor,
      );
    });

    test('a retired data type is an error — it is a configuration defect', () {
      expect(
        healthImportResultTone(
          tokens,
          const HealthImportResult.noMatchingTypes(),
        ),
        tokens.colors.alert.error.defaultColor,
      );
    });
  });

  group('guest/demo world', () {
    testWidgets(
      'collapses to the demo explainer — no rows, no import actions, '
      'nothing resolving the absent HealthImport',
      (tester) async {
        const size = Size(600, 1600);
        tester.view
          ..physicalSize = size
          ..devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            const HealthImportPage(),
            mediaQueryData: const MediaQueryData(size: size),
            overrides: [
              profileContextProvider.overrideWithValue(
                ProfileContext.forProfile(
                  profile: Profile(
                    id: 'demo-guest',
                    type: ProfileType.guest,
                    name: 'Demo',
                    dirName: 'guest_profiles/demo-guest',
                    createdAt: DateTime(2026),
                  ),
                  root: Directory.systemTemp,
                ),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Health import is not available in the demo workspace'),
          findsOneWidget,
        );
        expect(find.byType(DesignSystemInlineCallout), findsOneWidget);
        // None of the import surface renders: no category rows, no
        // "import all" button, no date-range fields.
        expect(find.byType(DesignSystemListItem), findsNothing);
        expect(find.byType(DesignSystemButton), findsNothing);
        expect(find.byType(DateTimeField), findsNothing);
        // No import ever reached the (absent) HealthImport service.
        verifyZeroInteractions(mockHealthImport);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
