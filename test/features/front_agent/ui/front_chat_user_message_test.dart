import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/front_agent/ui/front_chat_user_message.dart';
import 'package:material_ui/material_ui.dart';

import '../../../helpers/test_app.dart';

void main() {
  const id = 'u1';
  const words = 'Count the hatchlings';
  late List<String> copied;
  late List<String> edited;

  setUp(() {
    copied = [];
    edited = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pump(
    WidgetTester tester,
    FrontUserMessageStatus status, {
    bool desktop = false,
    VoidCallback? onStop,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Center(
          child: FrontChatUserMessage(
            messageId: id,
            text: words,
            status: status,
            onEdit: edited.add,
            onStop: onStop,
            bubble: const SizedBox(
              key: Key('bubble'),
              width: 240,
              height: 48,
              child: Text(words),
            ),
          ),
        ),
        mediaQueryData: desktop
            ? desktopLayoutMediaQueryData
            : phoneMediaQueryData,
      ),
    );
    await tester.pump();
  }

  Future<void> longPress(WidgetTester tester) async {
    await tester.longPress(find.byKey(const Key('bubble')));
    await tester.pumpAndSettle();
  }

  double iconsOpacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byKey(FrontChatUserMessageKeys.copy(id)),
          matching: find.byType(AnimatedOpacity),
        ),
      )
      .opacity;

  group('on a phone', () {
    testWidgets('a long press on a stopped turn offers Copy and Edit; Edit '
        'hands its words to the box', (tester) async {
      await pump(tester, FrontUserMessageStatus.stopped);
      expect(find.byKey(FrontChatUserMessageKeys.stopped(id)), findsOneWidget);
      expect(find.text('Stopped'), findsOneWidget);

      await longPress(tester);
      expect(find.byKey(FrontChatUserMessageKeys.menuCopy(id)), findsOneWidget);
      // Under the bubble and its caption, clear of the words it acts on.
      expect(
        tester.getTopLeft(find.byKey(FrontChatUserMessageKeys.menuCopy(id))).dy,
        greaterThan(
          tester
              .getBottomLeft(find.byKey(FrontChatUserMessageKeys.stopped(id)))
              .dy,
        ),
      );

      await tester.tap(find.byKey(FrontChatUserMessageKeys.menuEdit(id)));
      await tester.pumpAndSettle();

      expect(edited, [words]);
      expect(copied, isEmpty);
    });

    testWidgets('Copy puts its words on the clipboard and says so', (
      tester,
    ) async {
      await pump(tester, FrontUserMessageStatus.stopped);
      await longPress(tester);

      await tester.tap(find.byKey(FrontChatUserMessageKeys.menuCopy(id)));
      await tester.pumpAndSettle();

      expect(copied, [words]);
      expect(find.text('Message copied'), findsOneWidget);
      expect(edited, isEmpty);
    });

    testWidgets('an answered turn can be copied, not edited', (tester) async {
      await pump(tester, FrontUserMessageStatus.settled);
      expect(find.byKey(FrontChatUserMessageKeys.stopped(id)), findsNothing);

      await longPress(tester);

      expect(find.byKey(FrontChatUserMessageKeys.menuCopy(id)), findsOneWidget);
      expect(find.byKey(FrontChatUserMessageKeys.menuEdit(id)), findsNothing);
    });

    testWidgets('a long press while she works on it warns it cannot be '
        'edited until stopped, and opens no menu', (tester) async {
      await pump(tester, FrontUserMessageStatus.working);

      await longPress(tester);

      expect(find.text('Still working on this'), findsOneWidget);
      expect(find.text('Stop the companion first to edit it.'), findsOneWidget);
      expect(find.byKey(FrontChatUserMessageKeys.menuCopy(id)), findsNothing);
    });

    testWidgets('the warning offers Stop, so the way forward is one tap '
        'away', (tester) async {
      var stops = 0;
      await pump(
        tester,
        FrontUserMessageStatus.working,
        onStop: () => stops++,
      );
      await longPress(tester);

      await tester.tap(find.text('Stop'));
      await tester.pump();

      expect(stops, 1);
    });

    testWidgets('no icons under the bubble: the actions are a long press '
        'away', (tester) async {
      await pump(tester, FrontUserMessageStatus.stopped);

      expect(find.byKey(FrontChatUserMessageKeys.copy(id)), findsNothing);
      expect(find.byKey(FrontChatUserMessageKeys.edit(id)), findsNothing);
    });

    testWidgets('assistive technology can open the actions by name', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, FrontUserMessageStatus.stopped);

      tester.semantics.performAction(
        find.semantics.byAction(SemanticsAction.longPress).first,
        SemanticsAction.longPress,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(FrontChatUserMessageKeys.menuEdit(id)), findsOneWidget);
      semantics.dispose();
    });
  });

  group('on a desktop', () {
    Future<TestGesture> hover(WidgetTester tester) async {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byKey(const Key('bubble'))));
      await tester.pumpAndSettle();
      return mouse;
    }

    testWidgets('the icons keep their room, and show only while the '
        'pointer is over the turn', (tester) async {
      await pump(tester, FrontUserMessageStatus.stopped, desktop: true);
      final height = tester.getSize(find.byType(FrontChatUserMessage)).height;
      expect(iconsOpacity(tester), 0);

      final mouse = await hover(tester);
      expect(iconsOpacity(tester), 1);
      expect(
        tester.getSize(find.byType(FrontChatUserMessage)).height,
        height,
      );

      await mouse.moveTo(const Offset(1, 1));
      await tester.pumpAndSettle();
      expect(iconsOpacity(tester), 0);
    });

    testWidgets('hidden icons take no taps — a touch never hovers to show '
        'them first', (tester) async {
      await pump(tester, FrontUserMessageStatus.stopped, desktop: true);

      await tester.tap(
        find.byKey(FrontChatUserMessageKeys.copy(id)),
        warnIfMissed: false,
      );
      await tester.tap(
        find.byKey(FrontChatUserMessageKeys.edit(id)),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(copied, isEmpty);
      expect(edited, isEmpty);
    });

    testWidgets('focus in the icons shows them too', (tester) async {
      await pump(tester, FrontUserMessageStatus.stopped, desktop: true);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(iconsOpacity(tester), 1);
    });

    testWidgets("a stopped turn's icons copy it and edit it", (tester) async {
      await pump(tester, FrontUserMessageStatus.stopped, desktop: true);
      await hover(tester);

      await tester.tap(find.byKey(FrontChatUserMessageKeys.copy(id)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(FrontChatUserMessageKeys.edit(id)));
      await tester.pumpAndSettle();

      expect(copied, [words]);
      expect(edited, [words]);
    });

    testWidgets('while she works on it, Edit is dimmed, and a click says '
        'why not yet', (tester) async {
      await pump(tester, FrontUserMessageStatus.working, desktop: true);
      await hover(tester);

      final edit = tester.widget<DesignSystemIconAction>(
        find.byKey(FrontChatUserMessageKeys.edit(id)),
      );
      expect(edit.tooltip, 'Stop the companion first to edit it.');
      // Dimmed, so it reads unavailable before it is clicked.
      expect(
        tester
            .widget<Opacity>(
              find.ancestor(
                of: find.byKey(FrontChatUserMessageKeys.edit(id)),
                matching: find.byType(Opacity),
              ),
            )
            .opacity,
        lessThan(1),
      );

      await tester.tap(find.byKey(FrontChatUserMessageKeys.edit(id)));
      await tester.pumpAndSettle();

      expect(find.text('Still working on this'), findsOneWidget);
      expect(edited, isEmpty);
    });

    testWidgets('the icons sit beside the bubble, not under it', (
      tester,
    ) async {
      await pump(tester, FrontUserMessageStatus.stopped, desktop: true);

      final bubble = tester.getRect(find.byKey(const Key('bubble')));
      final copy = tester.getRect(
        find.byKey(FrontChatUserMessageKeys.copy(id)),
      );
      expect(copy.right, lessThanOrEqualTo(bubble.left));
      expect(copy.top, lessThan(bubble.bottom));
    });

    testWidgets('an answered turn has Copy only', (tester) async {
      await pump(tester, FrontUserMessageStatus.settled, desktop: true);

      expect(find.byKey(FrontChatUserMessageKeys.copy(id)), findsOneWidget);
      expect(find.byKey(FrontChatUserMessageKeys.edit(id)), findsNothing);
    });

    testWidgets('a secondary click opens the same menu', (tester) async {
      await pump(tester, FrontUserMessageStatus.stopped, desktop: true);

      await tester.tap(
        find.byKey(const Key('bubble')),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(FrontChatUserMessageKeys.menuEdit(id)), findsOneWidget);
    });
  });
}
