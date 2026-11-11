import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/companion/model/companion_customization.dart';
import 'package:lotti/features/companion/state/companion_customization_controller.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/ui/front_voice_controls.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for the voice switch.
@visibleForTesting
abstract final class FrontVoiceSwitchKeys {
  static const Key row = Key('front-chat-voice-row');
  static const Key toggle = Key('front-chat-voice-switch');
}

/// Her saved customization while she may be muted from her chat: once it is
/// known, since a mute must never be guessed at, and while the companion is
/// on — with it off she never speaks. Null otherwise. Watched, so a build
/// calling it follows both.
CompanionCustomization? _mutable(WidgetRef ref) {
  final companionOn =
      ref.watch(configFlagProvider(enableCompanionFlag)).value ?? false;
  final customization = ref.watch(companionCustomizationProvider);
  final loaded = ref.read(companionCustomizationProvider.notifier).loaded;
  return companionOn && loaded ? customization : null;
}

/// Mutes her, or lets her speak again: the companion customization's
/// `speaksReplies`, the same setting as the companion settings' switch, so
/// muting her here mutes her everywhere — and stops her mid-sentence
/// (`FrontVoice.listenForSpokenReply`).
void _setSpeaks(WidgetRef ref, CompanionCustomization current, bool speaks) =>
    ref
        .read(companionCustomizationProvider.notifier)
        .set(current.copyWith(speaksReplies: speaks));

/// Whether she answers a spoken question aloud, as the drawer's "Spoken
/// answers" row: her voice's one place in the chat. The way to have her say
/// her latest answer in [conversationId] again ([FrontVoiceButton]) sits
/// beside the switch, so her voice reads as one pair; none while there is
/// no conversation she could speak in (the inbox). Nothing at all while she
/// may not be muted from here.
class FrontVoiceSwitch extends ConsumerWidget {
  const FrontVoiceSwitch({this.conversationId, super.key});

  final String? conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customization = _mutable(ref);
    if (customization == null) return const SizedBox.shrink();
    final tokens = context.designTokens;
    final speaks = customization.speaksReplies;
    final label = context.messages.frontChatSpokenAnswers;
    void toggle() => _setSpeaks(ref, customization, !speaks);
    final voiceId = conversationId;
    return Semantics(
      toggled: speaks,
      child: DesignSystemListItem(
        key: FrontVoiceSwitchKeys.row,
        title: label,
        size: DesignSystemListItemSize.small,
        borderRadius: BorderRadius.circular(tokens.radii.s),
        hoverBackgroundColor: tokens.colors.surface.enabled,
        leading: Icon(
          speaks ? LottiIcons.volume : LottiIcons.volumeOff,
          size: IconSizes.s,
          color: tokens.colors.text.mediumEmphasis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: tokens.spacing.step2,
          children: [
            if (voiceId != null) FrontVoiceButton(conversationId: voiceId),
            // The row says what it is and whether it is on; the switch is
            // its picture, and a second target for the same tap.
            ExcludeSemantics(
              child: DesignSystemToggle(
                key: FrontVoiceSwitchKeys.toggle,
                value: speaks,
                semanticsLabel: label,
                onChanged: (_) => toggle(),
              ),
            ),
          ],
        ),
        onTap: toggle,
      ),
    );
  }
}
