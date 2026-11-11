import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/query/query_source_access.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/companion/model/companion_customization.dart';
import 'package:lotti/features/companion/state/companion_customization_controller.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_journal_access_provider.dart';
import 'package:lotti/features/front_agent/ui/front_voice_controls.dart';
import 'package:lotti/features/front_agent/ui/front_voice_switch.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';
import '../../tts/test_utils.dart';

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
    String? conversationId,
    bool companion = true,
    bool speaks = true,
    bool loaded = true,
  }) async {
    custom = _Custom(speaks: speaks, isLoaded: loaded);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: FrontVoiceSwitch(conversationId: conversationId),
            ),
          ),
        ),
        overrides: [
          configFlagProvider.overrideWith(
            (ref, flag) =>
                Stream.value(flag == enableCompanionFlag && companion),
          ),
          companionCustomizationProvider.overrideWith(() => custom),
          // What her replay beside the switch reads.
          ttsEngineProvider.overrideWithValue(FakeTtsEngine()),
          agentResolvedSetupProvider.overrideWith((ref, id) async => null),
          frontJournalAccessProvider.overrideWith(
            (ref) => Stream.value(
              const QueryAccessSnapshot(
                showPrivate: false,
                categories: {},
                entries: {},
              ),
            ),
          ),
          frontActiveConversationProvider.overrideWith((ref) async => 'c-1'),
          frontChatThreadProvider.overrideWith(
            (ref) async => FrontChatThread.empty,
          ),
        ],
      ),
    );
    await tester.pump();
  }

  DesignSystemToggle toggle(WidgetTester tester) => tester
      .widget<DesignSystemToggle>(find.byKey(FrontVoiceSwitchKeys.toggle));

  Icon glyph(WidgetTester tester) => tester.widget<Icon>(
    find.descendant(
      of: find.byKey(FrontVoiceSwitchKeys.row),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Icon &&
            (widget.icon == LottiIcons.volume ||
                widget.icon == LottiIcons.volumeOff),
      ),
    ),
  );

  testWidgets('is the "Spoken answers" row, announced as a toggle that is on '
      'while she answers aloud', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester);

    expect(find.text('Spoken answers'), findsOneWidget);
    expect(toggle(tester).value, isTrue);
    expect(glyph(tester).icon, LottiIcons.volume);
    expect(
      tester.getSemantics(find.byKey(FrontVoiceSwitchKeys.row)),
      isSemantics(
        label: 'Spoken answers',
        hasToggledState: true,
        isToggled: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('a tap on the row mutes her — the same setting as the '
      "companion settings' switch — and strikes the speaker through", (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('Spoken answers'));
    await tester.pump();

    expect(custom.saved.single.speaksReplies, isFalse);
    expect(toggle(tester).value, isFalse);
    expect(glyph(tester).icon, LottiIcons.volumeOff);
  });

  testWidgets('the switch itself is a second target for the same change', (
    tester,
  ) async {
    await pump(tester, speaks: false);

    toggle(tester).onChanged(true);
    await tester.pump();

    expect(custom.saved.single.speaksReplies, isTrue);
  });

  testWidgets('her replay sits beside the switch for the open conversation, '
      'and is left out where there is none', (tester) async {
    await pump(tester, conversationId: 'c-1');
    expect(
      tester.widget<FrontVoiceButton>(find.byType(FrontVoiceButton)),
      isA<FrontVoiceButton>().having(
        (button) => button.conversationId,
        'conversationId',
        'c-1',
      ),
    );

    await pump(tester);
    expect(find.byType(FrontVoiceButton), findsNothing);
    expect(find.byKey(FrontVoiceSwitchKeys.row), findsOneWidget);
  });

  testWidgets('is not offered before her saved setting is known: a mute '
      'is never guessed at', (tester) async {
    await pump(tester, loaded: false);
    expect(find.byKey(FrontVoiceSwitchKeys.row), findsNothing);
  });

  testWidgets('is not offered with the companion off: she never speaks', (
    tester,
  ) async {
    await pump(tester, companion: false);
    expect(find.byKey(FrontVoiceSwitchKeys.row), findsNothing);
  });
}
