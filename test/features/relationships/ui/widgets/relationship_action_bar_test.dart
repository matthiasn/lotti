import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/service/contact_launcher.dart';
import 'package:lotti/features/relationships/service/pending_interaction_store.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_action_bar.dart';
import 'package:lotti/features/relationships/util/contact_channel_uri.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

/// A launcher whose answers are scripted per action and whose calls are
/// recorded — the bar's two decisions, which channel to offer and what a
/// press does, are both observable.
class _FakeContactLauncher implements ContactLauncher {
  _FakeContactLauncher({required this.launchable, this.launchSucceeds = true});

  final Set<ContactAction> launchable;
  final bool launchSucceeds;
  final List<(ContactChannel, ContactAction)> launched = [];

  /// When set, every availability answer waits on it — so a test can hold a
  /// resolution open while the widget's channels change under it.
  Completer<void>? gate;

  @override
  Future<bool> canLaunch(ContactChannel channel, ContactAction action) async {
    if (gate case final gate?) await gate.future;
    return launchable.contains(action) &&
        contactChannelUri(channel, action) != null;
  }

  @override
  Future<bool> launch(ContactChannel channel, ContactAction action) async {
    launched.add((channel, action));
    return launchSucceeds;
  }
}

class _FakePendingInteractionStore implements PendingInteractionStore {
  PendingInteraction? remembered;

  @override
  Future<void> remember({
    required String relationshipId,
    required CheckInInteractionType interactionType,
  }) async {
    remembered = (
      relationshipId: relationshipId,
      interactionType: interactionType,
      startedAt: DateTime(2026, 8, 17),
    );
  }

  @override
  Future<PendingInteraction?> read() async => remembered;

  @override
  Future<void> clear() async => remembered = null;
}

void main() {
  final testDate = DateTime(2026, 8, 17, 12);
  const email = ContactChannel(
    type: ContactChannelType.email,
    value: 'pip@example.com',
  );
  const mobile = ContactChannel(
    type: ContactChannelType.mobile,
    value: '+15550109999',
  );

  RelationshipEntry person(List<ContactChannel> channels) => RelationshipEntry(
    meta: Metadata(
      id: 'rel-1',
      createdAt: testDate,
      updatedAt: testDate,
      dateFrom: testDate,
      dateTo: testDate,
    ),
    data: RelationshipData(
      title: 'Pip',
      contactChannels: channels,
      status: RelationshipStatus.active(
        id: 'status-1',
        createdAt: testDate,
        utcOffset: 0,
      ),
    ),
  );

  late _FakePendingInteractionStore store;
  var logged = 0;
  var spoke = 0;

  setUp(() {
    store = _FakePendingInteractionStore();
    logged = 0;
    spoke = 0;
  });

  Future<_FakeContactLauncher> pump(
    WidgetTester tester, {
    List<ContactChannel> channels = const [],
    Set<ContactAction> launchable = const {
      ContactAction.call,
      ContactAction.message,
      ContactAction.email,
    },
    bool launchSucceeds = true,
  }) async {
    final launcher = _FakeContactLauncher(
      launchable: launchable,
      launchSucceeds: launchSucceeds,
    );
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        RelationshipActionBar(
          relationship: person(channels),
          onLogCheckIn: () => logged++,
          onSpeak: () => spoke++,
        ),
        overrides: [
          contactLauncherProvider.overrideWithValue(launcher),
          pendingInteractionStoreProvider.overrideWithValue(store),
        ],
      ),
    );
    await tester.pumpAndSettle();
    return launcher;
  }

  final channelButton = find.byKey(const ValueKey('person-action-channel'));

  testWidgets('sits on the glass strip with the labelled primary pill and the '
      'mic, in the interactive accent', (tester) async {
    await pump(tester);

    expect(find.byType(DesignSystemGlassStrip), findsOneWidget);
    final pill = tester.widget<DsGlassPill>(
      find.byKey(const ValueKey('person-action-log-check-in')),
    );
    final tokens = tester.element(find.byType(DsGlassPill)).designTokens;
    expect(pill.label, 'Log check-in');
    expect(pill.fillColor, tokens.colors.interactive.enabled);
    expect(pill.expand, isTrue);
    expect(find.byKey(const ValueKey('person-action-speak')), findsOneWidget);
  });

  testWidgets('the pill and the mic call back', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('person-action-log-check-in')));
    await tester.tap(find.byKey(const ValueKey('person-action-speak')));
    await tester.pump();

    expect(logged, 1);
    expect(spoke, 1);
  });

  group('the channel control', () {
    testWidgets('is absent for a person without channels', (tester) async {
      await pump(tester);

      expect(channelButton, findsNothing);
    });

    testWidgets('is absent when nothing is launchable, so the user never taps '
        'a control that does nothing', (tester) async {
      await pump(tester, channels: const [mobile, email], launchable: const {});

      expect(channelButton, findsNothing);
    });

    testWidgets('offers the first channel the platform can open, in the '
        "person's own order — a call on a phone", (tester) async {
      await pump(tester, channels: const [mobile, email]);

      expect(channelButton, findsOneWidget);
      expect(find.byIcon(LottiIcons.call), findsOneWidget);
      expect(find.byIcon(LottiIcons.mail), findsNothing);
    });

    testWidgets('skips to email where there is no dialer — a desktop', (
      tester,
    ) async {
      await pump(
        tester,
        channels: const [mobile, email],
        launchable: const {ContactAction.email},
      );

      expect(find.byIcon(LottiIcons.mail), findsOneWidget);
      expect(find.byIcon(LottiIcons.call), findsNothing);
      expect(
        tester.widget<DsGlassRoundButton>(channelButton).semanticLabel,
        'Email',
      );
    });

    testWidgets('a press launches the channel and remembers the interaction '
        'for the post-call offer', (tester) async {
      final launcher = await pump(tester, channels: const [mobile]);

      await tester.tap(channelButton);
      await tester.pumpAndSettle();

      expect(launcher.launched, [(mobile, ContactAction.call)]);
      expect(store.remembered?.relationshipId, 'rel-1');
      expect(store.remembered?.interactionType, CheckInInteractionType.call);
    });

    testWidgets('a launch the platform refuses remembers nothing and says so', (
      tester,
    ) async {
      await pump(tester, channels: const [mobile], launchSucceeds: false);

      await tester.tap(channelButton);
      await tester.pumpAndSettle();

      expect(store.remembered, isNull);
      expect(
        find.text('Nothing on this device can open that'),
        findsOneWidget,
      );
    });

    testWidgets('a resolution that started before the channels changed is '
        'discarded, so a removed channel can never be offered', (
      tester,
    ) async {
      final launcher = _FakeContactLauncher(
        launchable: const {ContactAction.call, ContactAction.email},
      );
      Widget bar(List<ContactChannel> channels) =>
          makeTestableWidgetWithScaffold(
            RelationshipActionBar(
              relationship: person(channels),
              onLogCheckIn: () {},
              onSpeak: () {},
            ),
            overrides: [
              contactLauncherProvider.overrideWithValue(launcher),
              pendingInteractionStoreProvider.overrideWithValue(store),
            ],
          );

      // The first resolution (mobile → call) is held open...
      final first = Completer<void>();
      launcher.gate = first;
      await tester.pumpWidget(bar(const [mobile]));
      await tester.pump();

      // ...while the person loses the number; the second resolution runs
      // unhindered and lands first.
      launcher.gate = null;
      await tester.pumpWidget(bar(const []));
      await tester.pumpAndSettle();
      expect(channelButton, findsNothing);

      // The stale answer arrives last and must be ignored.
      first.complete();
      await tester.pumpAndSettle();

      expect(channelButton, findsNothing);
      expect(find.byIcon(LottiIcons.call), findsNothing);
    });

    testWidgets('re-resolves when the channels change under it', (
      tester,
    ) async {
      final launcher = _FakeContactLauncher(
        launchable: const {ContactAction.call, ContactAction.email},
      );
      Widget bar(List<ContactChannel> channels) =>
          makeTestableWidgetWithScaffold(
            RelationshipActionBar(
              relationship: person(channels),
              onLogCheckIn: () {},
              onSpeak: () {},
            ),
            overrides: [
              contactLauncherProvider.overrideWithValue(launcher),
              pendingInteractionStoreProvider.overrideWithValue(store),
            ],
          );

      await tester.pumpWidget(bar(const []));
      await tester.pumpAndSettle();
      expect(channelButton, findsNothing);

      await tester.pumpWidget(bar(const [email]));
      await tester.pumpAndSettle();
      expect(find.byIcon(LottiIcons.mail), findsOneWidget);
    });
  });
}
