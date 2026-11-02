import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/ai/ui/widgets/inference_profile_picker_modal.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/state/front_agent_providers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// Keys for the rows of her profile picker that are not a profile's.
abstract final class FrontProfileChoiceKeys {
  static const Key useDefault = Key('front-profile-use-default');
}

/// Her AI profile, chosen from her surface.
///
/// The chosen profile becomes her own setup: her routing thinks with its
/// thinking model, and its read-aloud model is her voice, so a profile that
/// names Voxtral TTS makes her answer aloud with it. The picker's first row
/// clears that choice: she then follows the Settings default profile, and
/// without that a built-in model, which has no voice of its own: she then
/// speaks with the on-device one. A chosen profile that is later deleted
/// counts as no choice (`resolveFrontAgentModel`).
abstract final class FrontProfileChoice {
  /// The profile she has chosen of her own, if any, whether or not it still
  /// exists.
  @visibleForTesting
  static String? ownProfileId(AgentConfig config) =>
      config.inferenceSetup?.baseProfileId ?? config.profileId;

  /// Lets the user pick her profile for [identity], or the Settings default,
  /// saves it and says so. Whether a pick changes anything is the
  /// service's call (`FrontAgentService.chooseProfile`).
  /// A failure is logged and surfaces as an error toast.
  ///
  /// Her identity's update stream re-resolves her setup, and with it her
  /// voice, once the choice is written.
  ///
  /// The caller watches the catalog ([profiles]) and [defaultProfileId] and
  /// hands over what is loaded, so the picker opens at once. A one-off read
  /// of the catalog here never settled when nothing listened to it and a
  /// config stream emitted again while it loaded: the tap did nothing.
  static Future<void> choose(
    BuildContext context,
    WidgetRef ref,
    AgentIdentityEntity identity, {
    required List<AiConfigInferenceProfile> profiles,
    required String? defaultProfileId,
  }) async {
    final messages = context.messages;
    final logger = ref.read(domainLoggerProvider);
    try {
      final own = ownProfileId(identity.config);
      final pick = await _showPicker(
        context,
        profiles: profiles,
        // A choice whose profile is gone falls back to the default.
        ownProfileId: profiles.any((p) => p.id == own) ? own : null,
        defaultProfileId: defaultProfileId,
      );
      // The service writes nothing when her setup already is the pick, and
      // repairs it when only the id matches — a disabled setup, an override.
      if (pick == null || !context.mounted) return;
      final saved = await ref
          .read(frontAgentServiceProvider)
          .chooseProfile(pick.profileId);
      if (!saved) throw StateError('The front agent does not exist');
      if (!context.mounted) return;
      final pickedId = pick.profileId;
      context.showToast(
        tone: DesignSystemToastTone.success,
        title: pickedId == null
            ? messages.frontChatProfileFollowsDefault
            // The picker answers with an id from this very list.
            : messages.frontChatProfileChanged(
                profiles.firstWhere((p) => p.id == pickedId).name,
              ),
      );
    } catch (error, stackTrace) {
      logger.error(
        LogDomain.agentWorkflow,
        error,
        stackTrace: stackTrace,
        subDomain: 'FrontProfileChoice',
        message: 'Choosing her profile failed',
      );
      if (context.mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: messages.commonError,
        );
      }
    }
  }

  /// The picker: the Settings default first, marked while she has no
  /// profile of her own, then every profile. Null when dismissed; a null
  /// `profileId` for the Settings default.
  static Future<({String? profileId})?> _showPicker(
    BuildContext context, {
    required List<AiConfigInferenceProfile> profiles,
    required String? ownProfileId,
    required String? defaultProfileId,
  }) {
    final messages = context.messages;
    final defaultName = profiles
        .where((p) => p.id == defaultProfileId)
        .firstOrNull
        ?.name;
    return ModalUtils.showSinglePageModal<({String? profileId})>(
      context: context,
      title: messages.inferenceProfileChooseTitle,
      padding: EdgeInsets.zero,
      builder: (modalContext) {
        final tokens = modalContext.designTokens;
        return InferenceProfilePickerList(
          profiles: profiles,
          selectedProfileId: ownProfileId,
          onSelected: (id) => Navigator.of(modalContext).pop((profileId: id)),
          header: DesignSystemSelectionRow(
            key: FrontProfileChoiceKeys.useDefault,
            title: messages.frontChatProfileUseDefault,
            subtitle: defaultName,
            type: DesignSystemSelectionRowType.singleSelect,
            selected: ownProfileId == null,
            selectedLabel: messages.designSystemSelectedLabel,
            leading: Icon(
              LottiIcons.settings,
              color: tokens.colors.text.mediumEmphasis,
              size: tokens.spacing.step6,
            ),
            semanticLabel: [
              messages.frontChatProfileUseDefault,
              ?defaultName,
            ].join(', '),
            onTap: () => Navigator.of(modalContext).pop((profileId: null)),
          ),
        );
      },
    );
  }
}
