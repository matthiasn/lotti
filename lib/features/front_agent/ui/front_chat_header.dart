import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/ui/agent_internals_panel.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/consumption_summary_pill.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/state/companion_look_controller.dart';
import 'package:lotti/features/companion/ui/companion_view.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for the header's controls.
@visibleForTesting
abstract final class FrontChatHeaderKeys {
  static const Key title = Key('front-chat-title');
  static const Key subtitle = Key('front-chat-subtitle');
  static const Key figure = Key('front-chat-figure');
  static const Key cost = Key('front-chat-cost');
  static const Key internals = Key('front-chat-internals');
  static const Key close = Key('front-chat-close');
}

/// The front chat's identity band: her face when the companion is switched
/// on, a spark tile when it is not; her name and what she does; what the
/// thread has cost so far; the way into her internals; and the sheet's
/// close.
///
/// The cost pill is the whole thread's — every routing turn she ran — the
/// attribution every agent's internals carry (decision 8 made the routing
/// model hers and cheap; this is where the user checks).
class FrontChatHeader extends ConsumerWidget {
  const FrontChatHeader({required this.onClose, super.key});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final totals = ref
        .watch(agentConsumptionTotalsProvider(frontAgentId))
        .value;
    final companionOn =
        ref.watch(configFlagProvider(enableCompanionFlag)).value ?? false;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.background.level01,
        border: Border(
          bottom: BorderSide(color: tokens.colors.decorative.level01),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // The pill rides the title line where there is room for a word
            // beside it — the same fold every page header uses — and drops
            // under the subtitle in the sheet, whose width would otherwise
            // squeeze what she does into an ellipsis.
            final pillInline = constraints.maxWidth >= kPageHeaderFoldWidth;
            final pill = totals == null
                ? null
                : ConsumptionSummaryPill(
                    key: FrontChatHeaderKeys.cost,
                    totals: totals,
                    foregroundColor: tokens.colors.text.mediumEmphasis,
                  );
            return Row(
              children: [
                _Figure(companionOn: companionOn),
                SizedBox(width: tokens.spacing.step3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        messages.frontChatTitle,
                        key: FrontChatHeaderKeys.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.typography.styles.subtitle.subtitle2
                            .copyWith(color: tokens.colors.text.highEmphasis),
                      ),
                      SizedBox(height: tokens.spacing.step1),
                      Text(
                        messages.frontChatSubtitle,
                        key: FrontChatHeaderKeys.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.typography.styles.others.caption.copyWith(
                          color: tokens.colors.text.lowEmphasis,
                        ),
                      ),
                      if (pill != null && !pillInline) ...[
                        SizedBox(height: tokens.spacing.step2),
                        pill,
                      ],
                    ],
                  ),
                ),
                if (pill != null && pillInline) ...[
                  SizedBox(width: tokens.spacing.step2),
                  pill,
                ],
                SizedBox(width: tokens.spacing.step2),
                DesignSystemIconAction(
                  key: FrontChatHeaderKeys.internals,
                  tooltip: messages.aiInternalsTitle,
                  onPressed: () => AgentInternalsPanel.show(
                    context: context,
                    agentId: frontAgentId,
                    agentName: messages.frontChatTitle,
                  ),
                  icon: LottiIcons.reasoning,
                ),
                DesignSystemIconAction(
                  key: FrontChatHeaderKeys.close,
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: onClose,
                  icon: LottiIcons.close,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Her bust in the session's outfit, or the spark tile every agent chat
/// header wears when the companion character is switched off.
class _Figure extends ConsumerWidget {
  const _Figure({required this.companionOn});

  final bool companionOn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    return ExcludeSemantics(
      child: Container(
        key: FrontChatHeaderKeys.figure,
        width: ControlSizes.avatar,
        height: ControlSizes.avatar,
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tokens.colors.aiCard.accentSoft,
          borderRadius: BorderRadius.circular(tokens.radii.m),
          border: Border.all(color: tokens.colors.aiCard.border),
        ),
        child: companionOn
            ? CompanionView(
                look: ref.watch(companionLookProvider),
                framing: CompanionFraming.bust,
              )
            : Icon(
                LottiIcons.aiSpark,
                size: IconSizes.l,
                color: tokens.colors.aiCard.accent,
              ),
      ),
    );
  }
}
