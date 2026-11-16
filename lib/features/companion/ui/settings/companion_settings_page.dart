import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/companion/model/companion_reaction.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/state/companion_customization_controller.dart';
import 'package:lotti/features/companion/ui/companion_speaker.dart';
import 'package:lotti/features/companion/ui/companion_view.dart';
import 'package:lotti/features/companion/ui/settings/companion_settings_tabs.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/tabs/design_system_tab.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/features/tts/ui/tts_model_download_prompt.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/widgets/pages/sliver_box_adapter_page.dart';
import 'package:lotti/widgets/settings/settings_page_layout.dart';
import 'package:material_ui/material_ui.dart';

/// The subject her preview here is dressed for: on "Surprise me", the
/// session's outfit for her settings, steady while choices are made.
@visibleForTesting
const companionSettingsDressedFor = 'companion-settings';

/// The utterance her preview speaks: the sample *Hear me* plays.
@visibleForTesting
const companionSettingsVoiceSource = 'companion-settings-voice';

/// What her settings are sorted into: how she looks, how she sounds, how
/// she takes things.
enum CompanionSettingsTab { look, voice, personality }

/// Stable keys of her settings page.
@visibleForTesting
abstract final class CompanionSettingsKeys {
  static const Key full = ValueKey('companionSettingsFull');
  static const Key bust = ValueKey('companionSettingsBust');
  static const Key hear = ValueKey('companion-settings-hear');
  static Key tab(CompanionSettingsTab tab) =>
      ValueKey('companion-settings-tab-${tab.name}');
  static Key content(CompanionSettingsTab tab) =>
      ValueKey('companion-settings-content-${tab.name}');
}

/// The mobile page for [CompanionSettingsBody], in the settings chrome. The
/// body fills what the header leaves, so she stays in sight while only her
/// choices scroll.
class CompanionSettingsPage extends StatelessWidget {
  const CompanionSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverBoxAdapterPage(
      title: context.messages.settingsCompanionTitle,
      showBackButton: true,
      fillRemaining: true,
      child: const CompanionSettingsBody(),
    );
  }
}

/// Where a person makes the companion their own, in one place: how she
/// looks, the voice she speaks with, and how much sass she reads with.
///
/// She stands pinned, head to toe and as a portrait, in what is chosen, and
/// never scrolls away from the choice that changes her: over the choices on
/// a phone, beside them where the pane is wide. Every change shows on her
/// at once and is stored ([companionCustomizationProvider]); *Hear me* has
/// her say a line in the voice chosen, her mouth following it; a sass
/// picked shows too — she takes a slip that way ([companionReaction],
/// [companionSignOff]). The choices are sorted into three tabs
/// ([CompanionSettingsTab]), so none of them is a screen away from her.
///
/// Needs a bounded height: the mobile page fills the viewport, and the
/// desktop settings panel hosts it unscrolled.
class CompanionSettingsBody extends ConsumerStatefulWidget {
  const CompanionSettingsBody({super.key});

  @override
  ConsumerState<CompanionSettingsBody> createState() =>
      _CompanionSettingsBodyState();
}

class _CompanionSettingsBodyState extends ConsumerState<CompanionSettingsBody> {
  final _preview = CompanionController();
  CompanionSettingsTab _tab = CompanionSettingsTab.look;

  /// The voice, kept for [dispose]: her sample must not outlast the page.
  late final TtsPlaybackController _voice;

  @override
  void initState() {
    super.initState();
    _voice = ref.read(ttsPlaybackControllerProvider.notifier);
  }

  @override
  void dispose() {
    // Deferred: a provider may not be written while the tree is torn down.
    final voice = _voice;
    Future.microtask(
      () => voice.stop(sourceId: companionSettingsVoiceSource),
    ).ignore();
    super.dispose();
  }

  /// Makes her [sass] and has her show it: how she takes a slip.
  void _setSass(CompanionSass sass) {
    ref
        .read(companionCustomizationProvider.notifier)
        .set(ref.read(companionCustomizationProvider).copyWith(sass: sass));
    final gesture = companionReaction(-2, sass: sass).gesture;
    if (gesture != null) _preview.play(gesture);
    final face = companionSignOff(const [-2], sass: sass);
    if (face != null) _preview.flourish(face);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final messages = context.messages;
    // The voice is hers to show off only where there is one to hear.
    final canHear =
        (ref.watch(configFlagProvider(enableAiSummaryTtsFlag)).value ??
            false) &&
        ref.watch(ttsEngineProvider).isSupported;

    // Equal tabs across the width where their labels fit; where a long
    // translation does not, they keep their labels whole and scroll.
    final tabs = LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: IntrinsicWidth(
            child: Row(
              children: [
                for (final tab in CompanionSettingsTab.values)
                  Expanded(
                    child: DesignSystemTab(
                      key: CompanionSettingsKeys.tab(tab),
                      selected: tab == _tab,
                      label: switch (tab) {
                        CompanionSettingsTab.look =>
                          messages.companionSettingsTabLook,
                        CompanionSettingsTab.voice =>
                          messages.companionSettingsVoiceLabel,
                        CompanionSettingsTab.personality =>
                          messages.companionSettingsTabPersonality,
                      },
                      onPressed: () => setState(() => _tab = tab),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    final content = SingleChildScrollView(
      // A tab's own scroll position: one tab's does not carry to the next.
      key: CompanionSettingsKeys.content(_tab),
      padding: EdgeInsets.only(top: spacing.step5, bottom: spacing.step6),
      child: switch (_tab) {
        CompanionSettingsTab.look => const CompanionLookTab(),
        CompanionSettingsTab.voice => const CompanionVoiceTab(),
        CompanionSettingsTab.personality => CompanionPersonalityTab(
          onSass: _setSass,
        ),
      },
    );
    final choices = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tabs,
        Expanded(child: content),
      ],
    );

    return SettingsContentArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Beside her choices where there is room for both; over them on
          // a phone, where she takes no more than her card's height.
          if (constraints.maxWidth >= kDesktopBreakpoint * 2 / 3) {
            return Padding(
              padding: EdgeInsets.only(top: spacing.step5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(
                      child: _Stage(
                        preview: _preview,
                        canHear: canHear,
                        beside: true,
                      ),
                    ),
                  ),
                  SizedBox(width: spacing.step6),
                  Expanded(flex: 3, child: choices),
                ],
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: spacing.step4),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: ControlSizes.companionCard,
                  ),
                  child: _Stage(
                    preview: _preview,
                    canHear: canHear,
                    beside: false,
                  ),
                ),
              ),
              Expanded(child: choices),
            ],
          );
        },
      ),
    );
  }
}

/// She, head to toe and as a portrait, in what is chosen, with *Hear me*
/// beside or under her: the one preview every choice changes.
class _Stage extends ConsumerWidget {
  const _Stage({
    required this.preview,
    required this.canHear,
    required this.beside,
  });

  final CompanionController preview;
  final bool canHear;

  /// Whether she stands beside her choices, in a column of her own, rather
  /// than over them.
  final bool beside;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.designTokens.spacing;
    final messages = context.messages;
    final speaking = ref.watch(
      ttsPlaybackControllerProvider.select(
        (playback) => playback.isActiveFor(companionSettingsVoiceSource),
      ),
    );
    final voice = ref.read(ttsPlaybackControllerProvider.notifier);
    final full = CompanionFraming.full.aspectRatio;

    // Decorative: the choices say in words what she shows.
    final figures = ExcludeSemantics(
      child: AspectRatio(
        // Both at one height: each takes the width its own shape needs.
        aspectRatio: full + 1,
        child: Row(
          spacing: spacing.step3,
          children: [
            Expanded(
              flex: (full * 1000).round(),
              child: CompanionSpeaker(
                key: CompanionSettingsKeys.full,
                sourceId: companionSettingsVoiceSource,
                dressedFor: companionSettingsDressedFor,
                stage: true,
                autoGestures: false,
                controller: preview,
              ),
            ),
            const Expanded(
              flex: 1000,
              child: CompanionSpeaker(
                key: CompanionSettingsKeys.bust,
                sourceId: companionSettingsVoiceSource,
                dressedFor: companionSettingsDressedFor,
                framing: CompanionFraming.bust,
                stage: true,
                autoGestures: false,
                // Not the full figure's: the two do not blink as one.
                seed: 23,
              ),
            ),
          ],
        ),
      ),
    );
    final hear = DesignSystemButton(
      key: CompanionSettingsKeys.hear,
      label: speaking
          ? messages.aiSummaryStopTooltip
          : messages.companionSettingsHearMe,
      leadingIcon: speaking ? LottiIcons.stop : LottiIcons.volume,
      variant: DesignSystemButtonVariant.secondary,
      onPressed: () => speaking
          ? voice.stop(sourceId: companionSettingsVoiceSource)
          : voice.speak(
              sourceId: companionSettingsVoiceSource,
              text: messages.speechSettingsCloudVoiceSample,
              confirmModelDownload: (model) =>
                  confirmTtsModelDownload(context, model),
            ),
    );

    // Over her choices she is as tall as her card, the button beside her;
    // in a column of her own she is larger, and it stands under her.
    if (!beside) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: spacing.step4,
        children: [
          Flexible(child: figures),
          if (canHear) hear,
        ],
      );
    }
    return Column(
      spacing: spacing.step4,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: ControlSizes.companionCard * 2,
          ),
          child: figures,
        ),
        if (canHear) hear,
      ],
    );
  }
}
