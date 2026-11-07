import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/companion/state/companion_customization_controller.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for the voice switch.
@visibleForTesting
abstract final class FrontVoiceSwitchKeys {
  static const Key toggle = Key('front-chat-voice-switch');
}

/// Whether she answers a spoken question aloud, switched where she speaks:
/// the same setting as the companion settings' switch, so muting her here
/// mutes her everywhere — and stops her mid-sentence
/// (`FrontVoice.listenForSpokenReply`).
///
/// Only once her saved setting is known, since a mute must never be guessed
/// at, and only while the companion is on: with it off she never speaks.
///
/// Where the row is tight (a phone), [showLabel] off trades the word for
/// the speaker glyph, the full sentence kept in its tooltip.
class FrontVoiceSwitch extends ConsumerWidget {
  const FrontVoiceSwitch({this.showLabel = true, super.key});

  /// Says "Voice" beside the switch; off, the speaker glyph says it.
  final bool showLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companionOn =
        ref.watch(configFlagProvider(enableCompanionFlag)).value ?? false;
    final customization = ref.watch(companionCustomizationProvider);
    final controller = ref.read(companionCustomizationProvider.notifier);
    if (!companionOn || !controller.loaded) return const SizedBox.shrink();
    final messages = context.messages;
    final tokens = context.designTokens;
    final toggle = DesignSystemToggle(
      key: FrontVoiceSwitchKeys.toggle,
      value: customization.speaksReplies,
      label: showLabel ? messages.frontChatVoiceLabel : null,
      semanticsLabel: messages.companionSettingsSpeakRepliesTitle,
      onChanged: (speaks) =>
          controller.set(customization.copyWith(speaksReplies: speaks)),
    );
    if (showLabel) return toggle;
    return Tooltip(
      message: messages.companionSettingsSpeakRepliesTitle,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(
              LottiIcons.volume,
              size: IconSizes.s,
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
          SizedBox(width: tokens.spacing.step2),
          toggle,
        ],
      ),
    );
  }
}
