import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/relationships/service/contact_launcher.dart';
import 'package:lotti/features/relationships/service/pending_interaction_store.dart';
import 'package:lotti/features/relationships/ui/widgets/contact_quick_actions.dart';
import 'package:lotti/features/relationships/util/contact_channel_uri.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';
import '../../helpers/fake_contact_launcher.dart';
import '../../helpers/fake_pending_interaction_store.dart';

void main() {
  const mobile = ContactChannel(
    type: ContactChannelType.mobile,
    value: '+15550109999',
  );
  const email = ContactChannel(
    type: ContactChannelType.email,
    value: 'pip@frostbeak.example',
  );

  late FakeContactLauncher launcher;
  late FakePendingInteractionStore store;

  setUp(() {
    launcher = FakeContactLauncher();
    store = FakePendingInteractionStore();
  });

  /// Launches [channel] for [action] from a button, the way the person
  /// page's contact row does.
  Future<void> launch(
    WidgetTester tester,
    ContactChannel channel,
    ContactAction action,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Consumer(
          builder: (context, ref, _) => TextButton(
            key: const ValueKey('go'),
            onPressed: () => launchContactAction(
              context,
              ref,
              relationshipId: 'pip',
              channel: channel,
              action: action,
            ),
            child: const Text('go'),
          ),
        ),
        overrides: [
          contactLauncherProvider.overrideWithValue(launcher),
          pendingInteractionStoreProvider.overrideWithValue(store),
        ],
      ),
    );
    await tester.tap(find.byKey(const ValueKey('go')));
    await tester.pumpAndSettle();
  }

  group('launchContactAction', () {
    testWidgets('launches the channel and remembers a placed call, so the '
        'next resume can offer a check-in', (tester) async {
      await launch(tester, mobile, ContactAction.call);

      expect(launcher.launched, [(mobile, ContactAction.call)]);
      expect(store.pending!.relationshipId, 'pip');
      expect(store.pending!.interactionType, CheckInInteractionType.call);
      expect(find.text('Nothing on this device can open that'), findsNothing);
    });

    testWidgets('remembers an email as a message, the nearest check-in kind', (
      tester,
    ) async {
      await launch(tester, email, ContactAction.email);

      expect(store.pending!.interactionType, CheckInInteractionType.message);
    });

    testWidgets('a refused launch remembers nothing — there was no '
        'conversation to log — and says so', (tester) async {
      launcher = FakeContactLauncher(launchSucceeds: false);

      await launch(tester, mobile, ContactAction.call);

      expect(store.pending, isNull);
      expect(find.text('Nothing on this device can open that'), findsOneWidget);
    });
  });

  group('interactionTypeForAction', () {
    test('maps every action to a check-in kind', () {
      expect(
        interactionTypeForAction(ContactAction.call),
        CheckInInteractionType.call,
      );
      expect(
        interactionTypeForAction(ContactAction.message),
        CheckInInteractionType.message,
      );
      expect(
        interactionTypeForAction(ContactAction.email),
        CheckInInteractionType.message,
      );
    });
  });

  testWidgets('every action has its own label and glyph', (tester) async {
    late List<(String, IconData)> faces;
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Builder(
          builder: (context) {
            faces = [
              for (final action in ContactAction.values)
                (
                  contactActionLabel(context, action),
                  contactActionIcon(action),
                ),
            ];
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(faces.map((f) => f.$1), ['Call', 'Message', 'Email']);
    expect(faces.map((f) => f.$2).toSet(), hasLength(3));
  });
}
