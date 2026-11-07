import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/companion/model/companion_customization.dart';
import 'package:lotti/features/companion/state/companion_customization_controller.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
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

void main() {
  late _Custom custom;

  Future<void> pump(
    WidgetTester tester, {
    bool companion = true,
    bool speaks = true,
    bool loaded = true,
    bool showLabel = true,
  }) async {
    custom = _Custom(speaks: speaks, isLoaded: loaded);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: Center(child: FrontVoiceSwitch(showLabel: showLabel)),
        ),
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

  DesignSystemToggle toggle(WidgetTester tester) => tester
      .widget<DesignSystemToggle>(find.byKey(FrontVoiceSwitchKeys.toggle));

  testWidgets('shows whether she answers aloud, under the word "Voice"', (
    tester,
  ) async {
    await pump(tester);

    expect(toggle(tester).value, isTrue);
    expect(toggle(tester).label, 'Voice');
    expect(
      toggle(tester).semanticsLabel,
      'Answer spoken questions aloud',
    );
  });

  testWidgets('switched off, she is muted — the same setting as the '
      "companion settings' switch", (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(FrontVoiceSwitchKeys.toggle));
    await tester.pump();

    expect(custom.saved.single.speaksReplies, isFalse);
    expect(toggle(tester).value, isFalse);
  });

  testWidgets('switched on again, she speaks again', (tester) async {
    await pump(tester, speaks: false);

    await tester.tap(find.byKey(FrontVoiceSwitchKeys.toggle));
    await tester.pump();

    expect(custom.saved.single.speaksReplies, isTrue);
  });

  testWidgets('without its word, the speaker glyph says what it is and the '
      'tooltip says it whole', (tester) async {
    await pump(tester, showLabel: false);

    expect(toggle(tester).label, isNull);
    expect(find.byIcon(LottiIcons.volume), findsOne);
    expect(find.byTooltip('Answer spoken questions aloud'), findsOne);
  });

  testWidgets('is not offered before her saved setting is known: a mute is '
      'never guessed at', (tester) async {
    await pump(tester, loaded: false);
    expect(find.byKey(FrontVoiceSwitchKeys.toggle), findsNothing);
  });

  testWidgets('is not offered with the companion off: she never speaks', (
    tester,
  ) async {
    await pump(tester, companion: false);
    expect(find.byKey(FrontVoiceSwitchKeys.toggle), findsNothing);
  });
}
