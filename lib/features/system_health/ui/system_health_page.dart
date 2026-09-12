import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/ui/widgets/agent_markdown_view.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/widgets/inference_provider_model_picker_modal.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_date_picker_modal.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/advanced/logging_settings_page.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/settings/ui/widgets/settings_icon.dart';
import 'package:lotti/features/sync/ui/clipboard_helper.dart';
import 'package:lotti/features/system_health/domain/system_health_range.dart';
import 'package:lotti/features/system_health/state/system_health_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/settings/settings_picker_field.dart';
import 'package:material_ui/material_ui.dart';

/// Mobile wrapper — `SliverBoxAdapterPage` chrome around [SystemHealthBody],
/// which the Settings V2 detail pane hosts on its own.
class SystemHealthPage extends StatelessWidget {
  const SystemHealthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverBoxAdapterPage(
      title: context.messages.settingsSystemHealthTitle,
      showBackButton: true,
      child: const SystemHealthBody(),
    );
  }
}

/// The on-demand log analysis tool.
///
/// Time range, model and the embedded logging-domain toggles feed one
/// [SystemHealthController.run]; the resulting report renders below with a
/// one-tap copy of the full Markdown.
class SystemHealthBody extends ConsumerStatefulWidget {
  const SystemHealthBody({super.key});

  @override
  ConsumerState<SystemHealthBody> createState() => _SystemHealthBodyState();
}

class _SystemHealthBodyState extends ConsumerState<SystemHealthBody> {
  bool _showDigest = false;

  static final DateFormat _day = DateFormat.yMMMd();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final state = ref.watch(systemHealthControllerProvider);
    final controller = ref.read(systemHealthControllerProvider.notifier);

    ref.listen(systemHealthControllerProvider, (previous, next) {
      final failure = next.failure;
      if (failure != null && failure != previous?.failure) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: messages.systemHealthFailedTitle,
          description: failure,
        );
      }
    });

    final inset = EdgeInsets.symmetric(horizontal: tokens.spacing.step5);
    final document = state.document;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: inset,
            child: Text(
              messages.systemHealthDescription,
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ),
          SizedBox(height: tokens.spacing.sectionGap),
          Padding(
            padding: inset,
            child: _SectionTitle(
              icon: LottiIcons.calendar,
              title: messages.systemHealthRangeTitle,
            ),
          ),
          SizedBox(height: tokens.spacing.step3),
          Padding(
            padding: inset,
            child: DsSegmentedToggle<SystemHealthPreset>(
              segments: [
                DsSegment(
                  SystemHealthPreset.last24Hours,
                  messages.systemHealthPresetLast24Hours,
                ),
                DsSegment(
                  SystemHealthPreset.last7Days,
                  messages.systemHealthPresetLast7Days,
                ),
                DsSegment(
                  SystemHealthPreset.last14Days,
                  messages.systemHealthPresetLast14Days,
                ),
                DsSegment(
                  SystemHealthPreset.custom,
                  messages.systemHealthPresetCustom,
                ),
              ],
              selected: state.preset,
              onChanged: controller.selectPreset,
              expand: true,
            ),
          ),
          if (state.preset == SystemHealthPreset.custom) ...[
            SizedBox(height: tokens.spacing.step3),
            Padding(
              padding: inset,
              child: Row(
                children: [
                  Expanded(
                    child: SettingsPickerField(
                      key: const Key('system_health_custom_from'),
                      label: messages.systemHealthCustomFromLabel,
                      valueText: _formatDay(state.customFirstDay),
                      onTap: () => unawaited(
                        _pickDay(
                          title: messages.systemHealthCustomFromLabel,
                          initial: state.customFirstDay,
                          onPicked: controller.setCustomFirstDay,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step3),
                  Expanded(
                    child: SettingsPickerField(
                      key: const Key('system_health_custom_to'),
                      label: messages.systemHealthCustomToLabel,
                      valueText: _formatDay(state.customLastDay),
                      onTap: () => unawaited(
                        _pickDay(
                          title: messages.systemHealthCustomToLabel,
                          initial: state.customLastDay,
                          onPicked: controller.setCustomLastDay,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: tokens.spacing.sectionGap),
          Padding(
            padding: inset,
            child: _SectionTitle(
              icon: LottiIcons.reasoning,
              title: messages.systemHealthModelTitle,
            ),
          ),
          SizedBox(height: tokens.spacing.step3),
          _ModelRow(state: state),
          SizedBox(height: tokens.spacing.sectionGap),
          Padding(
            padding: inset,
            child: _SectionTitle(
              icon: LottiIcons.bug,
              title: messages.systemHealthDomainsTitle,
              subtitle: messages.systemHealthDomainsDescription,
            ),
          ),
          // The same toggles as Settings → Advanced → Logging Domains; a
          // domain switched on here is logged *and* analysed.
          const LoggingSettingsBody(),
          Padding(
            padding: inset,
            child: DesignSystemButton(
              key: const Key('system_health_run'),
              label: messages.systemHealthRunButton,
              onPressed: state.isRunning
                  ? null
                  : () => unawaited(controller.run()),
              isLoading: state.isRunning,
              size: DesignSystemButtonSize.medium,
              fullWidth: true,
            ),
          ),
          if (document != null) ...[
            SizedBox(height: tokens.spacing.sectionGap),
            Padding(
              padding: inset,
              child: Row(
                children: [
                  Expanded(
                    child: _SectionTitle(
                      icon: LottiIcons.description,
                      title: messages.systemHealthReportTitle,
                    ),
                  ),
                  DesignSystemButton(
                    key: const Key('system_health_copy'),
                    label: messages.systemHealthCopyButton,
                    leadingIcon: LottiIcons.copy,
                    variant: DesignSystemButtonVariant.secondary,
                    onPressed: () => unawaited(
                      ClipboardHelper.copyTextAndNotify(
                        context,
                        document.markdown,
                        title: messages.systemHealthCopiedToast,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: tokens.spacing.step3),
            Padding(
              padding: inset,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.colors.background.level02,
                  borderRadius: BorderRadius.circular(tokens.radii.m),
                  border: Border.all(color: tokens.colors.decorative.level01),
                ),
                child: Padding(
                  padding: EdgeInsets.all(tokens.spacing.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AgentMarkdownView(
                        document.summaryMarkdown,
                        key: const Key('system_health_summary'),
                      ),
                      if (document.path case final path?) ...[
                        SizedBox(height: tokens.spacing.step2),
                        Text(
                          messages.systemHealthSavedTo(path),
                          key: const Key('system_health_saved_path'),
                          style: tokens.typography.styles.others.caption
                              .copyWith(
                                color: tokens.colors.text.lowEmphasis,
                              ),
                        ),
                      ],
                      SizedBox(height: tokens.spacing.step3),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: DesignSystemButton(
                          key: const Key('system_health_toggle_digest'),
                          label: _showDigest
                              ? messages.systemHealthHideDigest
                              : messages.systemHealthShowDigest,
                          variant: DesignSystemButtonVariant.tertiary,
                          onPressed: () =>
                              setState(() => _showDigest = !_showDigest),
                        ),
                      ),
                      if (_showDigest) ...[
                        SizedBox(height: tokens.spacing.step3),
                        AgentMarkdownView(
                          document.digestMarkdown,
                          key: const Key('system_health_digest'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _formatDay(DateTime? day) => day == null ? null : _day.format(day);

  Future<void> _pickDay({
    required String title,
    required DateTime? initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final now = DateTime.now();
    final result = await showDesignSystemDatePicker(
      context: context,
      title: title,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    final picked = result?.date;
    if (picked != null && mounted) onPicked(picked);
  }
}

/// The model the findings are written with: the default profile's thinking
/// model until the user picks another one from the shared picker.
class _ModelRow extends ConsumerWidget {
  const _ModelRow({required this.state});

  final SystemHealthState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final options = ref.watch(agentSetupOptionsProvider).value;
    final defaultModel = ref.watch(systemHealthDefaultModelProvider).value;
    final model = state.useDefaultModel
        ? defaultModel
        : options?.models.firstWhereOrNull(
            (value) => value.id == state.selectedModelId,
          );
    final canPick = options != null && options.models.isNotEmpty;

    return DesignSystemGroupedList(
      children: [
        DesignSystemListItem(
          key: const Key('system_health_model'),
          title: model?.name ?? messages.systemHealthModelNone,
          subtitle: model == null
              ? messages.systemHealthModelNoneDescription
              : messages.systemHealthModelDescription,
          subtitleMaxLines: null,
          leading: const SettingsIcon(icon: LottiIcons.aiStack),
          trailing: SettingsIcon.trailingChevron(tokens),
          onTap: canPick
              ? () => unawaited(_pick(context, ref, options, defaultModel))
              : null,
        ),
      ],
    );
  }

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    TaskAgentSetupOptions options,
    AiConfigModel? defaultModel,
  ) async {
    final selectedId = await InferenceProviderModelPickerModal.show(
      context: context,
      defaultModelId: defaultModel?.id,
      selectedModelId: state.useDefaultModel
          ? defaultModel?.id
          : state.selectedModelId,
      models: options.models,
      providers: options.providers,
      title: context.messages.systemHealthChooseModelTitle,
      defaultBadgeLabel: context.messages.taskAgentProfileDefaultBadge,
      autoSelectSingleCandidate: false,
    );
    if (selectedId == null || !context.mounted) return;
    final controller = ref.read(systemHealthControllerProvider.notifier);
    if (selectedId == defaultModel?.id) {
      controller.useDefaultModel();
    } else {
      controller.selectModel(selectedId);
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final subtitle = this.subtitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: tokens.colors.interactive.enabled),
            SizedBox(width: tokens.spacing.step3),
            Expanded(
              child: Text(
                title,
                style: tokens.typography.styles.subtitle.subtitle2,
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          SizedBox(height: tokens.spacing.step2),
          Text(
            subtitle,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
      ],
    );
  }
}
