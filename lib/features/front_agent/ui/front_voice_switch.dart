import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/companion/model/companion_customization.dart';
import 'package:lotti/features/companion/state/companion_customization_controller.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for the voice switch.
@visibleForTesting
abstract final class FrontVoiceSwitchKeys {
  static const Key toggle = Key('front-chat-voice-switch');
  static const Key menuItem = Key('front-chat-voice-menu-item');
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

/// Whether she answers a spoken question aloud, switched where she speaks,
/// under the word "Voice" — for a header with room for it.
class FrontVoiceSwitch extends ConsumerWidget {
  const FrontVoiceSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customization = _mutable(ref);
    if (customization == null) return const SizedBox.shrink();
    final messages = context.messages;
    return DesignSystemToggle(
      key: FrontVoiceSwitchKeys.toggle,
      value: customization.speaksReplies,
      label: messages.frontChatVoiceLabel,
      semanticsLabel: messages.companionSettingsSpeakRepliesTitle,
      onChanged: (speaks) => _setSpeaks(ref, customization, speaks),
    );
  }
}

/// The same switch as a checked row of an overflow menu, for a header with
/// no room for it on its row (a phone): null while the switch would not be
/// shown. Watches what it reads, so call it from a build.
DesignSystemContextMenuItem? frontVoiceMenuItem(
  BuildContext context,
  WidgetRef ref, {
  bool startsGroup = false,
}) {
  final customization = _mutable(ref);
  if (customization == null) return null;
  final speaks = customization.speaksReplies;
  return DesignSystemContextMenuItem(
    key: FrontVoiceSwitchKeys.menuItem,
    label: context.messages.companionSettingsSpeakRepliesTitle,
    checked: speaks,
    startsGroup: startsGroup,
    onTap: () => _setSpeaks(ref, customization, !speaks),
  );
}
