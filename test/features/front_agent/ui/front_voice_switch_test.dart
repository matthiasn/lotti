import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/companion/model/companion_customization.dart';
import 'package:lotti/features/companion/state/companion_customization_controller.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/front_agent/ui/front_voice_switch.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

/// Her saved customization, loaded or not, recording what was set.
class _Custom extends CompanionCustomizationController {
  _Custom({required this.speaks, required this.isLoaded});

  final bool speaks;
  final bool isLoaded;
  final saved = <CompanionCustomization>[];

  @override
  bool get loaded => isLoaded;

  @override
  CompanionCustomization build() =>
      CompanionCustomization(speaksReplies: speaks);

  @override
  void set(CompanionCustomization customization) {
    saved.add(customization);
    state = customization;
  }
}

/// Builds the overflow row the way a header does, keeping the last one built.
class _MenuRow extends ConsumerWidget {
  const _MenuRow({required this.onBuilt});

  final ValueChanged<DesignSystemContextMenuItem?> onBuilt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    onBuilt(frontVoiceMenuItem(context, ref, startsGroup: true));
    return const SizedBox.shrink();
  }
}

void main() {
  late _Custom custom;

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    bool companion = true,
    bool speaks = true,
    bool loaded = true,
  }) async {
    custom = _Custom(speaks: speaks, isLoaded: loaded);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(body: Center(child: child)),
        overrides: [
          configFlagProvider.overrideWith(
            (ref, flag) =>
                Stream.value(flag == enableCompanionFlag && companion),
          ),
          companionCustomizationProvider.overrideWith(() => custom),
        ],
      ),
    );
    await tester.pump();
  }

  group('the switch', () {
    DesignSystemToggle toggle(WidgetTester tester) => tester
        .widget<DesignSystemToggle>(find.byKey(FrontVoiceSwitchKeys.toggle));

    testWidgets('shows whether she answers aloud, under the word "Voice"', (
      tester,
    ) async {
      await pump(tester, const FrontVoiceSwitch());

      expect(toggle(tester).value, isTrue);
      expect(toggle(tester).label, 'Voice');
      expect(toggle(tester).semanticsLabel, 'Answer spoken questions aloud');
    });

    testWidgets('switched off, she is muted — the same setting as the '
        "companion settings' switch", (tester) async {
      await pump(tester, const FrontVoiceSwitch());

      await tester.tap(find.byKey(FrontVoiceSwitchKeys.toggle));
      await tester.pump();

      expect(custom.saved.single.speaksReplies, isFalse);
      expect(toggle(tester).value, isFalse);
    });

    testWidgets('switched on again, she speaks again', (tester) async {
      await pump(tester, const FrontVoiceSwitch(), speaks: false);

      await tester.tap(find.byKey(FrontVoiceSwitchKeys.toggle));
      await tester.pump();

      expect(custom.saved.single.speaksReplies, isTrue);
    });

    testWidgets('is not offered before her saved setting is known: a mute '
        'is never guessed at', (tester) async {
      await pump(tester, const FrontVoiceSwitch(), loaded: false);
      expect(find.byKey(FrontVoiceSwitchKeys.toggle), findsNothing);
    });

    testWidgets('is not offered with the companion off: she never speaks', (
      tester,
    ) async {
      await pump(tester, const FrontVoiceSwitch(), companion: false);
      expect(find.byKey(FrontVoiceSwitchKeys.toggle), findsNothing);
    });
  });

  group('the overflow row', () {
    DesignSystemContextMenuItem? row;

    Future<void> pumpRow(
      WidgetTester tester, {
      bool companion = true,
      bool speaks = true,
      bool loaded = true,
    }) => pump(
      tester,
      _MenuRow(onBuilt: (item) => row = item),
      companion: companion,
      speaks: speaks,
      loaded: loaded,
    );

    setUp(() => row = null);

    testWidgets('is a checked row saying what it switches, in a group of '
        'its own when asked', (tester) async {
      await pumpRow(tester);

      expect(row?.key, FrontVoiceSwitchKeys.menuItem);
      expect(row?.label, 'Answer spoken questions aloud');
      expect(row?.checked, isTrue);
      expect(row?.startsGroup, isTrue);
    });

    testWidgets('a tap mutes her, and the row follows', (tester) async {
      await pumpRow(tester);

      row!.onTap!();
      await tester.pump();

      expect(custom.saved.single.speaksReplies, isFalse);
      expect(row?.checked, isFalse);
    });

    testWidgets('a tap on a muted row lets her speak again', (tester) async {
      await pumpRow(tester, speaks: false);
      expect(row?.checked, isFalse);

      row!.onTap!();
      await tester.pump();

      expect(custom.saved.single.speaksReplies, isTrue);
    });

    testWidgets('is left out before her saved setting is known, and with the '
        'companion off', (tester) async {
      await pumpRow(tester, loaded: false);
      expect(row, isNull);

      await pumpRow(tester, companion: false);
      expect(row, isNull);
    });
  });
}
