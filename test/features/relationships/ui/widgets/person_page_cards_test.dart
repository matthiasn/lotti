import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/service/contact_launcher.dart';
import 'package:lotti/features/relationships/ui/widgets/contact_quick_actions.dart';
import 'package:lotti/features/relationships/ui/widgets/person_page_cards.dart';
import 'package:lotti/features/relationships/util/contact_channel_uri.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

/// Nothing is launchable: the channel rows render, the action buttons do
/// not, and the card's own content is what the tests see.
class _NoLauncher implements ContactLauncher {
  @override
  Future<bool> canLaunch(ContactChannel channel, ContactAction action) async =>
      false;

  @override
  Future<bool> launch(ContactChannel channel, ContactAction action) async =>
      false;
}

void main() {
  final at = DateTime(2026, 8, 13, 10, 30);

  CheckInEntry checkIn({String? attention, String? avoid}) => CheckInEntry(
    meta: Metadata(
      id: 'check-1',
      createdAt: at,
      updatedAt: at,
      dateFrom: at,
      dateTo: at,
    ),
    data: CheckInData(
      relationshipId: 'rel-1',
      interactionType: CheckInInteractionType.call,
      payAttentionTo: attention,
      avoid: avoid,
    ),
  );

  group('PersonCardHeader', () {
    testWidgets('lays out title, caption and trailing action', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const PersonCardHeader(
            title: 'Tasks',
            caption: Text('2 linked'),
            trailing: Text('Link task'),
          ),
        ),
      );

      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('2 linked'), findsOneWidget);
      expect(find.text('Link task'), findsOneWidget);
      // The action is pushed to the far edge; the caption stays by the title.
      expect(
        tester.getTopLeft(find.text('Link task')).dx,
        greaterThan(tester.getTopRight(find.text('2 linked')).dx),
      );
    });
  });

  group('NextTimeCard', () {
    test('hasContent is false for no check-in or blank guidance', () {
      expect(NextTimeCard.hasContent(null), isFalse);
      expect(NextTimeCard.hasContent(checkIn()), isFalse);
      expect(NextTimeCard.hasContent(checkIn(attention: '  ')), isFalse);
      expect(NextTimeCard.hasContent(checkIn(attention: 'The move')), isTrue);
      expect(NextTimeCard.hasContent(checkIn(avoid: 'The coffee')), isTrue);
    });

    testWidgets('renders nothing when the latest check-in carries no '
        'guidance — the page skips the gap on the same rule', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(NextTimeCard(latest: checkIn())),
      );

      expect(find.byKey(const ValueKey('person-next-time-card')), findsNothing);
    });

    testWidgets('shows both tiles with their captions and the check-in time', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          NextTimeCard(
            latest: checkIn(
              attention: 'Ask how the fitting went.',
              avoid: 'The coffee incident.',
            ),
          ),
        ),
      );

      expect(find.text('Next time'), findsOneWidget);
      expect(find.text('Pay attention to'), findsOneWidget);
      expect(find.text('Ask how the fitting went.'), findsOneWidget);
      expect(find.text('Better to avoid'), findsOneWidget);
      expect(find.text('The coffee incident.'), findsOneWidget);
      // The trailing stamp is the check-in's own day and time.
      expect(find.textContaining('10:30'), findsOneWidget);
    });

    testWidgets('a single field renders alone, untrimmed content trimmed', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          NextTimeCard(latest: checkIn(avoid: '  Politics.  ')),
        ),
      );

      expect(
        find.byKey(const ValueKey('person-next-time-attention')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('person-next-time-avoid')), findsOne);
      expect(find.text('Politics.'), findsOneWidget);
    });
  });

  group('ReachCard', () {
    Future<void> pump(WidgetTester tester, List<ContactChannel> channels) =>
        tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ReachCard(relationshipId: 'rel-1', channels: channels),
            overrides: [
              contactLauncherProvider.overrideWithValue(_NoLauncher()),
            ],
          ),
        );

    testWidgets('renders nothing for a person without channels', (
      tester,
    ) async {
      await pump(tester, const []);

      expect(find.byKey(const ValueKey('person-reach-card')), findsNothing);
    });

    testWidgets('names the section, states the privacy line and lists every '
        'channel with value and label', (tester) async {
      await pump(tester, const [
        ContactChannel(
          type: ContactChannelType.email,
          value: 'anna@example.com',
          label: 'Personal',
        ),
        ContactChannel(type: ContactChannelType.mobile, value: '+49 151 1'),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('Reach'), findsOneWidget);
      expect(
        find.text('Stays on this device · never shared with the AI'),
        findsOneWidget,
      );
      expect(find.text('anna@example.com'), findsOneWidget);
      expect(find.text('Personal'), findsOneWidget);
      expect(find.text('+49 151 1'), findsOneWidget);
      // A channel without a label falls back to its localized type name.
      expect(find.text('Mobile'), findsOneWidget);
      expect(find.byIcon(LottiIcons.mail), findsOneWidget);
      expect(find.byIcon(LottiIcons.phone), findsOneWidget);
      // Every row carries the quick actions, which decide for themselves.
      expect(find.byType(ContactQuickActions), findsNWidgets(2));
    });
  });
}
