import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../helpers/fallbacks.dart';
import '../mocks/mocks.dart';
import '../widget_test_utils.dart';

/// The plugin's single method channel.
///
/// Mocking it is what makes the Darwin code paths testable at all:
/// [NotificationService] reaches the OS only through this channel, so the
/// recorded call list *is* the contract this suite is about — above all,
/// whether `requestPermissions` ever crosses it.
const _pluginChannel = MethodChannel(
  'dexterous.com/flutter/local_notifications',
);

/// Fake platform implementation used for the non-Darwin platforms, so the
/// plugin's `late` static `instance` field is initialised.
///
/// `resolvePlatformSpecificImplementation<LinuxFlutterLocalNotificationsPlugin>`
/// returns null for this fake (it is not the concrete Linux type), so the
/// plugin short-circuits without touching native channels — which is exactly
/// the shape of a platform Lotti does not notify on.
class _FakeNotificationsPlatform extends FlutterLocalNotificationsPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<void> cancel({required int id}) async {}

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    String? payload,
  }) async {}
}

/// Records every method call the plugin sends to the platform.
class _ChannelRecorder {
  final List<MethodCall> calls = [];

  /// When set, the recorder throws for this method instead of answering,
  /// standing in for a plugin that failed to register (the flatpak case).
  String? failingMethod;

  List<String> get methods => [for (final call in calls) call.method];

  int countOf(String method) => methods.where((m) => m == method).length;

  /// Arguments of the only call to [method]. Deliberately strict: a second
  /// call would mean the production code did something twice, and silently
  /// reading the first would hide it.
  Map<Object?, Object?> argsOf(String method) {
    final matching = calls.where((call) => call.method == method);
    expect(matching, hasLength(1), reason: 'expected exactly one $method call');
    return matching.single.arguments as Map<Object?, Object?>;
  }

  Map<Object?, Object?>? platformSpecificsOf(String method) =>
      argsOf(method)['platformSpecifics'] as Map<Object?, Object?>?;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pluginChannel, (call) async {
          calls.add(call);
          if (call.method == failingMethod) {
            throw PlatformException(code: 'unavailable');
          }
          return switch (call.method) {
            'initialize' || 'requestPermissions' => true,
            _ => null,
          };
        });
  }

  void remove() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pluginChannel, null);
  }
}

/// Points `defaultTargetPlatform` **and** the plugin's platform instance at
/// [platform].
///
/// `resolvePlatformSpecificImplementation` requires the two to agree — it
/// returns null unless the registered instance is the concrete type matching
/// the current platform — so overriding either alone leaves the Darwin
/// branches unreachable. That is why they had gone untested, and why the
/// permission prompt could regress unnoticed.
void _usePlatform(TargetPlatform platform) {
  debugDefaultTargetPlatformOverride = platform;
  FlutterLocalNotificationsPlatform.instance = switch (platform) {
    TargetPlatform.iOS => IOSFlutterLocalNotificationsPlugin(),
    TargetPlatform.macOS => MacOSFlutterLocalNotificationsPlugin(),
    TargetPlatform.android => AndroidFlutterLocalNotificationsPlugin(),
    _ => _FakeNotificationsPlatform(),
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerAllFallbackValues();
    tzdata.initializeTimeZones();
  });

  // A single, stable JournalDb mock. The production file holds the database in
  // a top-level `final JournalDb _db = getIt<JournalDb>();` that is lazily read
  // on first access and then cached for the whole isolate. Re-registering a
  // fresh mock per test would therefore not be seen by `_db` after the first
  // method call, so we reuse one mock and only re-stub it each time.
  final sharedDb = MockJournalDb();
  late MockDomainLogger domainLogger;
  late _ChannelRecorder channel;

  /// Stubs the notifications config flag. Defaults to **off**, matching what a
  /// fresh install actually has — the state the prompt bug appeared in.
  void setNotificationsEnabled({required bool enabled}) {
    when(
      () => sharedDb.getConfigFlag(enableNotificationsFlag),
    ).thenAnswer((_) async => enabled);
  }

  /// Stubs the in-progress task count the badge is derived from.
  void setWipCount(int count) {
    // ignore: unnecessary_lambdas
    when(() => sharedDb.getWipCount()).thenAnswer((_) async => count);
  }

  setUp(() async {
    channel = _ChannelRecorder()..install();
    _usePlatform(TargetPlatform.linux);
    // Pinned so a scheduled notification's resolved zone does not depend on
    // the machine running the suite.
    tz.setLocalLocation(tz.UTC);
    domainLogger = MockDomainLogger();

    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<DomainLogger>()
          ..registerSingleton<DomainLogger>(domainLogger);
      },
    );
    // Replace the helper's JournalDb with our stable shared instance so it is
    // the one `_db` resolves to.
    if (getIt.isRegistered<JournalDb>()) {
      getIt.unregister<JournalDb>();
    }
    getIt.registerSingleton<JournalDb>(sharedDb);

    setNotificationsEnabled(enabled: false);
    setWipCount(0);
  });

  tearDown(() async {
    channel.remove();
    debugDefaultTargetPlatformOverride = null;
    reset(sharedDb);
    await tearDownTestGetIt();
  });

  /// Builds the service and waits for the constructor's fire-and-forget
  /// `initialize` to finish, so channel assertions are not racing it.
  Future<NotificationService> buildService() async {
    final service = NotificationService(
      timezoneLookup: () async => tz.local.name,
    );
    await service.initialized;
    return service;
  }

  group('NotificationConstants', () {
    test('exposes the documented badge/encouragement values', () {
      expect(NotificationConstants.badgeNotificationId, 1);
      expect(NotificationConstants.taskThreshold, 5);
      expect(NotificationConstants.defaultActionName, 'Open notification');
      expect(NotificationConstants.taskSingular, 'task');
      expect(NotificationConstants.taskPlural, 'tasks');
      expect(NotificationConstants.inProgressSuffix, ' in progress');
      expect(NotificationConstants.encouragementLow, 'Nice');
      expect(
        NotificationConstants.encouragementHigh,
        "Let's get that number down",
      );
    });
  });

  group('NotificationLocationResolver', () {
    setUp(() => tz.setLocalLocation(tz.getLocation('Europe/Berlin')));

    test('returns a named location without logging', () {
      final resolver = NotificationLocationResolver();

      expect(resolver.resolve('Asia/Tokyo').name, 'Asia/Tokyo');
      verifyNever(
        () => domainLogger.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      );
    });

    test('logs each unresolved zone once and returns local', () {
      final resolver = NotificationLocationResolver();

      expect(resolver.resolve('CEST').name, 'Europe/Berlin');
      expect(resolver.resolve('CEST').name, 'Europe/Berlin');

      verify(
        () => domainLogger.error(
          LogDomain.notifications,
          any<Object>(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'resolveLocation',
        ),
      ).called(1);
    });
  });

  // Root cause #1. `DarwinInitializationSettings` defaults all three
  // permission requests to true, and the native `initialize` forwards them to
  // `UNUserNotificationCenter.requestAuthorization` — so merely constructing
  // the service raised the system prompt. macOS previously overrode only
  // `requestSoundPermission`.
  group('plugin initialization', () {
    for (final platform in [TargetPlatform.macOS, TargetPlatform.iOS]) {
      test(
        '$platform initialize asks the OS for no permission at all',
        () async {
          _usePlatform(platform);

          await buildService();

          final args = channel.argsOf('initialize');
          expect(args['requestAlertPermission'], isFalse);
          expect(args['requestBadgePermission'], isFalse);
          expect(args['requestSoundPermission'], isFalse);
          // With every option false the native side returns without calling
          // requestAuthorization, so construction cannot prompt.
          expect(
            args.entries.where((e) => e.key.toString().startsWith('request')),
            everyElement(
              isA<MapEntry<Object?, Object?>>().having(
                (e) => e.value,
                'value',
                isFalse,
              ),
            ),
          );
        },
      );
    }

    test('constructing the service never requests permissions', () async {
      _usePlatform(TargetPlatform.macOS);

      await buildService();

      expect(channel.methods, isNot(contains('requestPermissions')));
    });

    test('a platform that is not notified on stays off the channel', () async {
      await buildService();

      expect(channel.calls, isEmpty);
    });

    test('an initialize that fails is logged, not thrown', () async {
      _usePlatform(TargetPlatform.macOS);
      channel.failingMethod = 'initialize';

      // The failure arrives asynchronously — the plugin completes the returned
      // future with an error rather than throwing — so this only passes
      // because the catch wraps the await, not the call.
      await expectLater(buildService(), completes);

      verify(
        () => domainLogger.error(
          LogDomain.notifications,
          any<Object>(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'initialization',
        ),
      ).called(1);
    });
  });

  // Android was never actually wired: `InitializationSettings` carried no
  // `android` entry, and the plugin throws `ArgumentError('Android settings
  // must be set…')` in exactly that case. Because `_initializePlugin` swallows
  // its own failures, that left the whole plugin silently uninitialised on
  // Android — no reminders, no habit alerts, no error the user ever saw.
  group('Android', () {
    setUp(() {
      _usePlatform(TargetPlatform.android);
      setNotificationsEnabled(enabled: true);
    });

    test('initialize reaches the platform with the status-bar icon', () async {
      await buildService();

      // A drawable, not @mipmap/ic_launcher: Android masks the small icon by
      // its alpha channel and paints the result white, so a full-bleed
      // launcher icon arrives as a solid white square.
      expect(channel.argsOf('initialize')['defaultIcon'], 'ic_stat_lotti');
    });

    test('initialize still asks for no permission', () async {
      await buildService();

      // The Darwin invariant holds here too: the runtime POST_NOTIFICATIONS
      // prompt must come from an explicit request after the config flag is
      // consulted, never as a side effect of the plugin waking up.
      expect(
        channel.methods,
        isNot(contains('requestNotificationsPermission')),
      );
      expect(channel.methods, isNot(contains('requestPermissions')));
    });

    test('an alert carries the localized channel at high importance', () async {
      final service = await buildService();
      channel.calls.clear();

      await service.showNotificationNow(
        title: 'Check in with Anna?',
        body: 'A good moment to reach out.',
        notificationId: 7,
        showOnMobile: true,
        showOnDesktop: false,
      );

      final specifics = channel.platformSpecificsOf('show')!;
      expect(specifics['channelId'], 'lotti_reminders');
      // Channel name and description are user-visible in Android's own
      // settings, so they come from the ARB catalogs.
      expect(specifics['channelName'], 'Reminders');
      expect(
        specifics['channelDescription'],
        'Check-in reminders, habit reminders and alerts from Lotti.',
      );
      // The counterpart of the Darwin timeSensitive interruption level: a
      // heads-up banner rather than a silent row in the shade.
      expect(specifics['importance'], Importance.high.value);
      expect(specifics['priority'], Priority.high.value);
    });

    test('a desktop-only alert carries no Android presentation', () async {
      final service = await buildService();
      channel.calls.clear();

      await service.showNotificationNow(
        title: 'title',
        body: 'body',
        notificationId: 8,
        showOnMobile: false,
        showOnDesktop: true,
      );

      expect(channel.platformSpecificsOf('show'), isNull);
    });

    test('scheduling asks for an inexact, doze-surviving alarm', () async {
      final service = await buildService();
      channel.calls.clear();

      await service.scheduleNotificationAt(
        title: 'title',
        body: 'body',
        // Fixed, and far out. The instant is irrelevant to what this test
        // asserts, but the plugin validates it against the real wall clock
        // through `tz.TZDateTime.now` — nothing a test can inject or fake
        // reaches that call — so the date has to be genuinely future. A
        // nearby literal is a time bomb: this was written as
        // DateTime(2026, 8, 21, 9) and went red the morning that arrived.
        notifyAt: DateTime(2100),
        notificationId: 9,
        showOnMobile: true,
        showOnDesktop: false,
      );

      // The exact modes need SCHEDULE_EXACT_ALARM, which Android 13+ does not
      // grant on install and the Play Store restricts to alarm/calendar apps.
      // `allowWhileIdle` is the half that matters: without it Doze defers the
      // reminder on exactly the idle phone it exists for.
      expect(
        channel.platformSpecificsOf('zonedSchedule')!['scheduleMode'],
        AndroidScheduleMode.inexactAllowWhileIdle.name,
      );
      expect(channel.methods, isNot(contains('requestExactAlarmsPermission')));
    });

    test('permission is requested explicitly, once the flag allows', () async {
      final service = await buildService();
      channel.calls.clear();

      await service.showNotificationNow(
        title: 'title',
        body: 'body',
        notificationId: 10,
        showOnMobile: true,
        showOnDesktop: false,
      );

      expect(channel.countOf('requestNotificationsPermission'), 1);
    });

    test('nothing crosses the channel while the flag is off', () async {
      setNotificationsEnabled(enabled: false);
      final service = await buildService();
      channel.calls.clear();

      await service.showNotificationNow(
        title: 'title',
        body: 'body',
        notificationId: 11,
        showOnMobile: true,
        showOnDesktop: false,
      );

      expect(channel.calls, isEmpty);
    });

    test(
      'a failing locale lookup degrades to English, not to no row',
      () async {
        // This runs inside NotificationRepository's vector-clock scope, which
        // commits only when its body returns — so an exception escaping here
        // would abort the notification row itself.
        final service = NotificationService(
          messages: () => throw StateError('no widgets binding'),
        );
        await service.initialized;
        channel.calls.clear();

        await expectLater(
          service.showNotificationNow(
            title: 'title',
            body: 'body',
            notificationId: 12,
            showOnMobile: true,
            showOnDesktop: false,
          ),
          completes,
        );

        final specifics = channel.platformSpecificsOf('show')!;
        expect(specifics['channelName'], 'Reminders');
        verify(
          () => domainLogger.error(
            LogDomain.notifications,
            any<Object>(),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'resolveChannelMessages',
          ),
        ).called(1);
      },
    );

    test('updateBadge is a no-op — Android has no icon badge', () async {
      setWipCount(3);
      final service = await buildService();
      channel.calls.clear();

      await service.updateBadge();

      // The badge is a Darwin concept: a number carried by a notification's
      // own `badge` field and posted with presentAlert false. The same call on
      // Android posts a visible "3 tasks in progress" notification after every
      // entry write — and would also prompt for POST_NOTIFICATIONS there.
      expect(channel.calls, isEmpty);
    });
  });

  // Root cause #2. Every entry point now consults the config flag *before*
  // anything can request permission.
  group('permission gate', () {
    final entryPoints = <String, Future<void> Function(NotificationService)>{
      'updateBadge': (service) => service.updateBadge(),
      'scheduleNotification': (service) => service.scheduleNotification(
        title: 'title',
        body: 'body',
        notifyAt: DateTime(2024, 3, 15, 9, 30),
        notificationId: 42,
        showOnMobile: true,
        showOnDesktop: true,
        repeat: true,
      ),
      'scheduleNotificationAt': (service) => service.scheduleNotificationAt(
        title: 'title',
        body: 'body',
        notifyAt: DateTime.utc(2030, 5, 4, 9, 30),
        notificationId: 42,
        showOnMobile: true,
        showOnDesktop: true,
      ),
      'showNotificationNow': (service) => service.showNotificationNow(
        title: 'title',
        body: 'body',
        notificationId: 42,
        showOnMobile: true,
        showOnDesktop: true,
      ),
    };

    for (final platform in [TargetPlatform.macOS, TargetPlatform.iOS]) {
      group('$platform', () {
        for (final entry in entryPoints.entries) {
          test('${entry.key} never prompts while the flag is off', () async {
            _usePlatform(platform);
            setNotificationsEnabled(enabled: false);
            final service = await buildService();
            channel.calls.clear();

            await entry.value(service);

            expect(channel.methods, isNot(contains('requestPermissions')));
            verify(
              () => sharedDb.getConfigFlag(enableNotificationsFlag),
            ).called(1);
          });

          test('${entry.key} prompts once the flag is on', () async {
            _usePlatform(platform);
            setNotificationsEnabled(enabled: true);
            final service = await buildService();
            channel.calls.clear();

            await withClock(Clock.fixed(DateTime.utc(2000)), () async {
              await entry.value(service);
            });

            expect(channel.methods, contains('requestPermissions'));
            final args = channel.argsOf('requestPermissions');
            expect(args['alert'], isTrue);
            expect(args['badge'], isTrue);
          });
        }
      });
    }

    for (final platform in [TargetPlatform.linux, TargetPlatform.windows]) {
      test('$platform is short-circuited before the flag is read', () async {
        _usePlatform(platform);
        setNotificationsEnabled(enabled: true);
        final service = await buildService();
        channel.calls.clear();

        for (final entry in entryPoints.values) {
          await entry(service);
        }

        // Cheapest check first: a platform Lotti does not notify on is not
        // worth a database read either.
        verifyNever(() => sharedDb.getConfigFlag(any()));
        expect(channel.calls, isEmpty);
      });
    }

    test('permission is requested once per process, not per call', () async {
      _usePlatform(TargetPlatform.macOS);
      setNotificationsEnabled(enabled: true);
      final service = await buildService();

      await service.updateBadge();
      await service.showNotificationNow(
        title: 'title',
        body: 'body',
        notificationId: 42,
        showOnMobile: true,
        showOnDesktop: true,
      );

      expect(channel.countOf('requestPermissions'), 1);
    });

    test('a failing request neither propagates nor sticks', () async {
      _usePlatform(TargetPlatform.macOS);
      setNotificationsEnabled(enabled: true);
      setWipCount(3);
      final service = await buildService();
      channel
        ..calls.clear()
        ..failingMethod = 'requestPermissions';

      // Asking is best-effort; the callers are not. NotificationRepository
      // schedules inside a vector-clock scope that commits only when its body
      // returns, so an error escaping here would abort notification creation.
      await expectLater(service.updateBadge(), completes);

      // And the work it guards still happens — a permission Lotti could not
      // ask for is the OS's problem to enforce, not a reason to skip the post.
      expect(channel.methods, ['requestPermissions', 'cancel', 'show']);
      verify(
        () => domainLogger.error(
          LogDomain.notifications,
          any<Object>(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'requestPermissions',
        ),
      ).called(1);

      // The rejection must not be what got memoized, or one transient channel
      // failure would disable notifications for the rest of the process.
      channel
        ..failingMethod = null
        ..calls.clear();
      setWipCount(4);
      await service.updateBadge();

      expect(channel.methods, contains('requestPermissions'));
    });

    test('the request is memoized, not globally suppressed', () async {
      // Guards the test above from passing vacuously: if the channel simply
      // stopped recording repeats, this would still read 1.
      _usePlatform(TargetPlatform.macOS);
      setNotificationsEnabled(enabled: true);

      await (await buildService()).updateBadge();
      await (await buildService()).updateBadge();

      expect(channel.countOf('requestPermissions'), 2);
    });
  });

  group('updateBadge while notifications are off', () {
    test('zeroes an icon badge inherited from a previous run', () async {
      _usePlatform(TargetPlatform.macOS);
      setNotificationsEnabled(enabled: false);
      final service = await buildService();
      channel.calls.clear();

      await service.updateBadge();

      // The badge outlives the process that set it, so a fresh run cannot
      // assume the icon is clean. Quitting with three tasks showing and
      // returning with notifications off has to still take the number down.
      expect(channel.methods, ['cancel', 'show']);
      expect(channel.platformSpecificsOf('show')!['badgeNumber'], 0);
      expect(service.badgeCount, 0);
      // ignore: unnecessary_lambdas
      verifyNever(() => sharedDb.getWipCount());
    });

    test('clears a badge posted while they were on', () async {
      _usePlatform(TargetPlatform.macOS);
      setNotificationsEnabled(enabled: true);
      setWipCount(3);
      final service = await buildService();
      await service.updateBadge();
      expect(service.badgeCount, 3, reason: 'badge posted while enabled');

      setNotificationsEnabled(enabled: false);
      channel.calls.clear();
      await service.updateBadge();

      // Cancelling alone would not do it: `removeDeliveredNotifications` drops
      // the record but leaves the number on the icon, which is carried by the
      // notification's own `badge` field. Only a zero post clears it.
      expect(channel.methods, ['cancel', 'show']);
      final specifics = channel.platformSpecificsOf('show')!;
      expect(specifics['badgeNumber'], 0);
      expect(specifics['presentAlert'], isFalse);
      expect(service.badgeCount, 0);
    });

    test('does nothing more once the icon already reads zero', () async {
      _usePlatform(TargetPlatform.macOS);
      setNotificationsEnabled(enabled: true);
      final service = await buildService();
      setWipCount(3);
      await service.updateBadge();
      setWipCount(0);
      await service.updateBadge();

      setNotificationsEnabled(enabled: false);
      channel.calls.clear();
      await service.updateBadge();

      // The task count reaching zero already posted the zero badge, so
      // switching notifications off has nothing left to take down.
      expect(channel.calls, isEmpty);
    });

    test('clears once, not on every entry write', () async {
      _usePlatform(TargetPlatform.macOS);
      setNotificationsEnabled(enabled: true);
      setWipCount(3);
      final service = await buildService();
      await service.updateBadge();

      setNotificationsEnabled(enabled: false);
      channel.calls.clear();
      await service.updateBadge();
      await service.updateBadge();
      await service.updateBadge();

      // updateBadge runs after every entry write; repeating the pair would put
      // two platform round trips on each one forever after.
      expect(channel.countOf('cancel'), 1);
      expect(channel.countOf('show'), 1);
    });

    test('re-enabling posts the current count again', () async {
      _usePlatform(TargetPlatform.macOS);
      setNotificationsEnabled(enabled: true);
      setWipCount(3);
      final service = await buildService();
      await service.updateBadge();

      setNotificationsEnabled(enabled: false);
      await service.updateBadge();

      setNotificationsEnabled(enabled: true);
      channel.calls.clear();
      await service.updateBadge();

      // badgeCount was reset on the way down, so the unchanged-count
      // short-circuit must not swallow the restore.
      expect(channel.argsOf('show')['title'], '3 tasks in progress');
      expect(service.badgeCount, 3);
    });
  });

  group('updateBadge while notifications are on', () {
    late NotificationService service;

    Future<void> withWipCount(int count) async {
      setWipCount(count);
      await service.updateBadge();
    }

    setUp(() async {
      _usePlatform(TargetPlatform.macOS);
      setNotificationsEnabled(enabled: true);
      service = await buildService();
    });

    test(
      'an unchanged count short-circuits before any platform call',
      () async {
        await withWipCount(2);
        channel.calls.clear();

        await withWipCount(2);

        expect(channel.calls, isEmpty);
        expect(service.badgeCount, 2);
      },
    );

    test(
      'a zero count posts a silent badge rather than only cancelling',
      () async {
        await withWipCount(4);
        channel.calls.clear();

        await withWipCount(0);

        // `badgeNumber: 0` is how the icon is cleared, so the count reaching
        // zero still has to cross the channel.
        expect(channel.methods, ['cancel', 'show']);
        final specifics = channel.platformSpecificsOf('show')!;
        expect(specifics['badgeNumber'], 0);
        expect(specifics['presentAlert'], isFalse);
        expect(channel.argsOf('show')['title'], '');
        expect(channel.argsOf('show')['body'], '');
      },
    );

    test('one task reads as singular and encourages', () async {
      await withWipCount(1);

      expect(channel.argsOf('show')['title'], '1 task in progress');
      expect(channel.argsOf('show')['body'], 'Nice');
    });

    test('below the threshold reads as plural and still encourages', () async {
      await withWipCount(4);

      expect(channel.argsOf('show')['title'], '4 tasks in progress');
      expect(channel.argsOf('show')['body'], 'Nice');
    });

    test('at the threshold the message turns into a nudge', () async {
      await withWipCount(NotificationConstants.taskThreshold);

      expect(channel.argsOf('show')['title'], '5 tasks in progress');
      expect(channel.argsOf('show')['body'], "Let's get that number down");
    });

    test('macOS alerts for a non-zero badge and carries the count', () async {
      await withWipCount(3);

      final specifics = channel.platformSpecificsOf('show')!;
      expect(specifics['presentAlert'], isTrue);
      expect(specifics['presentBadge'], isTrue);
      expect(specifics['badgeNumber'], 3);
    });

    test('iOS shows the number without ever alerting', () async {
      _usePlatform(TargetPlatform.iOS);
      service = await buildService();
      channel.calls.clear();

      await withWipCount(3);

      // On the phone the number on the icon is the whole message; an alert
      // for it would be noise.
      final specifics = channel.platformSpecificsOf('show')!;
      expect(specifics['presentAlert'], isFalse);
      expect(specifics['presentBadge'], isTrue);
      expect(specifics['badgeNumber'], 3);
    });
  });

  group('scheduleNotification', () {
    setUp(() async {
      _usePlatform(TargetPlatform.macOS);
      setNotificationsEnabled(enabled: true);
    });

    for (final now in [
      DateTime(2024, 12, 31, 6),
      DateTime(2024, 12, 31, 20),
    ]) {
      test('preserves tomorrow after completion at ${now.hour}:00', () async {
        final service = await buildService();
        channel.calls.clear();
        await withClock(Clock.fixed(now), () async {
          await service.scheduleNotification(
            title: 'Meditate',
            body: 'Daily meditation',
            notifyAt: DateTime(2025, 1, 1, 7, 45, 12),
            notificationId: 42,
            showOnMobile: false,
            showOnDesktop: true,
          );
        });
        final args = channel.argsOf('zonedSchedule');
        expect(args['id'], 42);
        expect(args['scheduledDateTime'], '2025-01-01T07:45:12');
        expect(args['matchDateTimeComponents'], isNull);
        expect(channel.methods, [
          'requestPermissions',
          'cancel',
          'zonedSchedule',
        ]);
        expect(
          channel.calls.firstWhere((call) => call.method == 'cancel').arguments,
          42,
        );
      });
    }

    test('uses the device lookup independently of the process zone', () async {
      _usePlatform(TargetPlatform.iOS);
      final service = NotificationService(
        timezoneLookup: () async => 'Asia/Tokyo',
      );
      await service.initialized;
      await withClock(
        Clock.fixed(DateTime.utc(2024)),
        () => service.scheduleNotification(
          title: 'Meditate',
          body: 'Daily meditation',
          notifyAt: DateTime(2024, 3, 15, 7, 45),
          notificationId: 42,
          showOnMobile: true,
          showOnDesktop: false,
        ),
      );
      final args = channel.argsOf('zonedSchedule');
      final scheduled = DateTime.parse(
        args['scheduledDateTimeISO8601']! as String,
      );
      expect(scheduled.toUtc(), DateTime.utc(2024, 3, 14, 22, 45));
    });

    for (final date in [
      DateTime(2024, 3, 31, 7, 45),
      DateTime(2024, 10, 27, 7, 45),
    ]) {
      test('preserves device wall clock across DST on $date', () async {
        _usePlatform(TargetPlatform.iOS);
        final berlin = tz.getLocation('Europe/Berlin');
        tz.setLocalLocation(berlin);
        final service = await buildService();
        await withClock(Clock.fixed(DateTime.utc(2024)), () async {
          await service.scheduleNotification(
            title: 'Meditate',
            body: 'Daily meditation',
            notifyAt: date,
            notificationId: 42,
            showOnMobile: true,
            showOnDesktop: false,
          );
        });
        final args = channel.argsOf('zonedSchedule');
        final scheduled = DateTime.parse(
          args['scheduledDateTimeISO8601']! as String,
        );
        final expected = tz.TZDateTime(
          berlin,
          date.year,
          date.month,
          date.day,
          7,
          45,
        );
        expect(
          scheduled.toUtc().millisecondsSinceEpoch,
          expected.millisecondsSinceEpoch,
        );
        expect(args['scheduledDateTime'], endsWith('T07:45:00'));
      });
    }

    test('repeat asks the OS to match on time of day', () async {
      final service = await buildService();

      await service.scheduleNotification(
        title: 'Meditate',
        body: 'Daily meditation',
        notifyAt: DateTime(2024, 3, 15, 7, 45),
        notificationId: 42,
        showOnMobile: true,
        showOnDesktop: false,
        repeat: true,
      );

      expect(
        channel.argsOf('zonedSchedule')['matchDateTimeComponents'],
        DateTimeComponents.time.index,
      );
    });

    test('a desktop-only alert carries no mobile presentation', () async {
      _usePlatform(TargetPlatform.iOS);
      final service = await buildService();

      await service.scheduleNotification(
        title: 'Meditate',
        body: 'Daily meditation',
        notifyAt: DateTime(2024, 3, 15, 7, 45),
        notificationId: 42,
        showOnMobile: false,
        showOnDesktop: true,
        repeat: true,
      );

      // iOS reads `NotificationDetails.iOS`, which is null when the caller
      // did not opt into mobile — this is what keeps a desktop reminder off
      // the phone.
      expect(channel.platformSpecificsOf('zonedSchedule'), isEmpty);
    });
  });

  group('scheduleNotificationAt', () {
    setUp(() async {
      _usePlatform(TargetPlatform.macOS);
      setNotificationsEnabled(enabled: true);
    });

    test('fires at the requested instant and carries the deep link', () async {
      final service = await buildService();
      final notifyAt = DateTime.utc(2030, 5, 4, 9, 30);

      await service.scheduleNotificationAt(
        title: 'Review',
        body: 'Time to review',
        notifyAt: notifyAt,
        notificationId: 7,
        showOnMobile: true,
        showOnDesktop: true,
        deepLink: '/tasks/abc',
      );

      final args = channel.argsOf('zonedSchedule');
      expect(args['id'], 7);
      expect(args['title'], 'Review');
      expect(args['payload'], '/tasks/abc');
      // Asserted as an instant, not as wall clock: converting into the
      // resolved zone must not move when the alert fires.
      expect(
        DateTime.parse(args['scheduledDateTimeISO8601']! as String).toUtc(),
        notifyAt,
      );
      final specifics = channel.platformSpecificsOf('zonedSchedule')!;
      expect(specifics['subtitle'], 'Review');
      expect(
        specifics['interruptionLevel'],
        InterruptionLevel.timeSensitive.index,
      );
    });

    test('cancels the previous alert for the same id first', () async {
      final service = await buildService();
      channel.calls.clear();

      await service.scheduleNotificationAt(
        title: 'Review',
        body: 'Time to review',
        notifyAt: DateTime.utc(2030, 5, 4, 9, 30),
        notificationId: 7,
        showOnMobile: true,
        showOnDesktop: true,
      );

      // Rescheduling must replace, not duplicate — so the cancel has to name
      // the same id, and land before the replacement is scheduled.
      expect(channel.methods, [
        'requestPermissions',
        'cancel',
        'zonedSchedule',
      ]);
      expect(
        channel.calls.firstWhere((call) => call.method == 'cancel').arguments,
        7,
      );
    });
  });

  group('showNotificationNow', () {
    setUp(() async {
      _usePlatform(TargetPlatform.macOS);
      setNotificationsEnabled(enabled: true);
    });

    test('shows immediately with the deep link attached', () async {
      final service = await buildService();
      channel.calls.clear();

      await service.showNotificationNow(
        title: 'Overdue',
        body: 'A task needs you',
        notificationId: 9,
        showOnMobile: true,
        showOnDesktop: true,
        deepLink: '/tasks/xyz',
      );

      expect(channel.methods, ['requestPermissions', 'cancel', 'show']);
      final args = channel.argsOf('show');
      expect(args['id'], 9);
      expect(args['title'], 'Overdue');
      expect(args['body'], 'A task needs you');
      expect(args['payload'], '/tasks/xyz');
      expect(channel.platformSpecificsOf('show')!['presentAlert'], isTrue);
    });

    test('a mobile-only alert carries no desktop presentation', () async {
      final service = await buildService();

      await service.showNotificationNow(
        title: 'Overdue',
        body: 'A task needs you',
        notificationId: 9,
        showOnMobile: true,
        showOnDesktop: false,
      );

      // macOS reads `NotificationDetails.macOS`, null here, so nothing is
      // presented on the desktop.
      expect(channel.platformSpecificsOf('show'), isNull);
    });
  });

  group('cancelNotification', () {
    test('cancels through the channel on a Darwin platform', () async {
      _usePlatform(TargetPlatform.macOS);
      final service = await buildService();
      channel.calls.clear();

      await service.cancelNotification(7);

      expect(channel.methods, ['cancel']);
      expect(channel.calls.single.arguments, 7);
    });

    for (final platform in [TargetPlatform.linux, TargetPlatform.windows]) {
      test('$platform returns without reading the database', () async {
        _usePlatform(platform);
        final service = await buildService();

        // Cancelling is unconditional elsewhere — no flag read — because
        // removing an alert must work even after notifications are switched
        // off. Here the platform guard is reached first.
        await expectLater(service.cancelNotification(7), completes);
        verifyNever(() => sharedDb.getConfigFlag(any()));
        expect(channel.calls, isEmpty);
      });
    }
  });

  group('scheduleHabitNotification', () {
    late MockNotificationService delegate;

    setUp(() {
      // scheduleHabitNotification delegates to getIt<NotificationService>().
      delegate = MockNotificationService();
      when(
        () => delegate.scheduleNotification(
          title: any(named: 'title'),
          body: any(named: 'body'),
          notifyAt: any(named: 'notifyAt'),
          notificationId: any(named: 'notificationId'),
          showOnMobile: any(named: 'showOnMobile'),
          showOnDesktop: any(named: 'showOnDesktop'),
          repeat: any(named: 'repeat'),
          deepLink: any(named: 'deepLink'),
        ),
      ).thenAnswer((_) async {});
      getIt.registerSingleton<NotificationService>(delegate);
    });

    HabitDefinition habit({required HabitSchedule schedule}) => HabitDefinition(
      id: 'habit-1',
      name: 'Meditate',
      description: 'Daily meditation',
      createdAt: DateTime(2024, 3),
      updatedAt: DateTime(2024, 3),
      habitSchedule: schedule,
      vectorClock: null,
      active: true,
      private: false,
    );

    test(
      'daily schedule with alertAtTime delegates with the alert hour/minute',
      () async {
        final alertAt = DateTime(2024, 1, 1, 7, 45, 12);
        final definition = habit(
          schedule: HabitSchedule.daily(
            requiredCompletions: 1,
            alertAtTime: alertAt,
          ),
        );

        final service = await buildService();
        await withClock(
          Clock.fixed(DateTime(2024, 12, 30, 23, 59, 59, 999)),
          () async {
            await service.scheduleHabitNotification(definition, daysToAdd: 2);
          },
        );

        final captured = verify(
          () => delegate.scheduleNotification(
            title: 'Meditate',
            body: 'Daily meditation',
            showOnMobile: true,
            showOnDesktop: false,
            notifyAt: captureAny(named: 'notifyAt'),
            notificationId: 'habit-1'.hashCode,
          ),
        ).captured;

        final notifyAt = captured.single as DateTime;
        // The time-of-day is copied from alertAtTime regardless of "now".
        expect(notifyAt.toUtc(), DateTime.utc(2025, 1, 1, 7, 45, 12));
      },
    );

    for (final scenario in [
      (
        now: DateTime.utc(2024, 3, 30, 22, 30),
        days: 1,
        expected: DateTime.utc(2024, 3, 31, 5, 45),
      ),
      (
        now: DateTime.utc(2024, 10, 26, 22, 30),
        days: 1,
        expected: DateTime.utc(2024, 10, 28, 6, 45),
      ),
      (
        now: DateTime.utc(2024, 12, 31, 19),
        days: 0,
        expected: DateTime.utc(2025, 1, 1, 6, 45),
      ),
      (
        now: DateTime.utc(2024, 12, 31, 6, 45),
        days: 0,
        expected: DateTime.utc(2025, 1, 1, 6, 45),
      ),
      (
        now: DateTime.utc(2024, 12, 31, 5),
        days: 0,
        expected: DateTime.utc(2024, 12, 31, 6, 45),
      ),
    ]) {
      test(
        'next habit reminder from ${scenario.now} plus ${scenario.days} calendar days',
        () async {
          tz.setLocalLocation(tz.getLocation('Europe/Berlin'));
          final service = await buildService();
          final definition = habit(
            schedule: HabitSchedule.daily(
              requiredCompletions: 1,
              alertAtTime: DateTime(2024, 1, 1, 7, 45),
            ),
          );
          await withClock(
            Clock.fixed(scenario.now),
            () => service.scheduleHabitNotification(
              definition,
              daysToAdd: scenario.days,
            ),
          );
          final captured =
              verify(
                    () => delegate.scheduleNotification(
                      title: 'Meditate',
                      body: 'Daily meditation',
                      showOnMobile: true,
                      showOnDesktop: false,
                      notifyAt: captureAny(named: 'notifyAt'),
                      notificationId: 'habit-1'.hashCode,
                    ),
                  ).captured.single
                  as DateTime;
          expect(captured.toUtc(), scenario.expected);
        },
      );
    }

    test('daily schedule without alertAtTime does not delegate', () async {
      final definition = habit(
        schedule: const HabitSchedule.daily(requiredCompletions: 1),
      );

      final service = await buildService();
      await service.scheduleHabitNotification(definition);

      verifyNever(
        () => delegate.scheduleNotification(
          title: any(named: 'title'),
          body: any(named: 'body'),
          notifyAt: any(named: 'notifyAt'),
          notificationId: any(named: 'notificationId'),
          showOnMobile: any(named: 'showOnMobile'),
          showOnDesktop: any(named: 'showOnDesktop'),
        ),
      );
    });

    test(
      'weekly schedule takes the orElse branch and does not delegate',
      () async {
        final definition = habit(
          schedule: const HabitSchedule.weekly(requiredCompletions: 1),
        );

        final service = await buildService();
        await service.scheduleHabitNotification(definition);

        verifyNever(
          () => delegate.scheduleNotification(
            title: any(named: 'title'),
            body: any(named: 'body'),
            notifyAt: any(named: 'notifyAt'),
            notificationId: any(named: 'notificationId'),
            showOnMobile: any(named: 'showOnMobile'),
            showOnDesktop: any(named: 'showOnDesktop'),
          ),
        );
      },
    );
  });
}
