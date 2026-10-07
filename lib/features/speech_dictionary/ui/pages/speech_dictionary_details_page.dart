import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/components/textareas/design_system_textarea.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/keyboard/ui/save_shortcut_scope.dart';
import 'package:lotti/features/labels/ui/widgets/category_selection_chip.dart';
import 'package:lotti/features/speech_dictionary/domain/speech_dictionary_terms.dart';
import 'package:lotti/features/speech_dictionary/repository/speech_dictionary_repository.dart';
import 'package:lotti/features/speech_dictionary/state/speech_dictionary_controller.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/settings/settings_detail_scaffold.dart';
import 'package:lotti/widgets/settings/settings_form_action_bar.dart';
import 'package:lotti/widgets/settings/settings_form_section.dart';
import 'package:material_ui/material_ui.dart';

const _listUrl = '/settings/speech-dictionary';

/// Full-page editor of one dictionary entry on the Settings detail surface,
/// in add or edit mode — the term, the categories it is limited to and the
/// spellings it is misheard as.
///
/// Edit mode (with [entryId]) waits for the entry to arrive from
/// [speechDictionaryEntryProvider]; add mode (with an optional
/// [initialTerm] prefill — what the list's search field held when its
/// create button or "no match" action was taken) needs none.
/// Save and delete beam back to the list rather than popping, since the
/// desktop detail pane is inline.
class SpeechDictionaryDetailsPage extends ConsumerStatefulWidget {
  const SpeechDictionaryDetailsPage({
    this.entryId,
    this.initialTerm,
    super.key,
  });

  final String? entryId;
  final String? initialTerm;

  bool get isCreateMode => entryId == null;

  @override
  ConsumerState<SpeechDictionaryDetailsPage> createState() =>
      _SpeechDictionaryDetailsPageState();
}

class _SpeechDictionaryDetailsPageState
    extends ConsumerState<SpeechDictionaryDetailsPage> {
  late final TextEditingController _termController;
  late final TextEditingController _misheardController;
  SpeechDictionaryEditorArgs? _args;
  bool _didSeedControllers = false;

  @override
  void initState() {
    super.initState();
    _termController = TextEditingController();
    _misheardController = TextEditingController();
    if (widget.isCreateMode) {
      _args = SpeechDictionaryEditorArgs(initialTerm: widget.initialTerm);
    }
  }

  @override
  void dispose() {
    _termController.dispose();
    _misheardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCreateMode) {
      return _buildScaffold(context, args: _args!, existing: null);
    }

    final entry = ref
        .watch(speechDictionaryEntryProvider(widget.entryId!))
        .value;
    if (entry == null) {
      return Scaffold(
        backgroundColor: context.designTokens.colors.background.level01,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    // Seed the form once per entry; a sync landing later keeps the edits.
    if (_args?.entry?.id != entry.id) {
      _args = SpeechDictionaryEditorArgs(entry: entry);
      _didSeedControllers = false;
    }
    return _buildScaffold(context, args: _args!, existing: entry);
  }

  Widget _buildScaffold(
    BuildContext context, {
    required SpeechDictionaryEditorArgs args,
    required SpeechDictionaryEntry? existing,
  }) {
    final messages = context.messages;
    final tokens = context.designTokens;
    final provider = speechDictionaryEditorControllerProvider(args);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    if (!_didSeedControllers) {
      _termController.text = state.term;
      _misheardController.text = formatSpeechTerms(state.misheardAs);
      _didSeedControllers = true;
    }

    Future<void> handleSave() async {
      final saved = await controller.save();
      if (!context.mounted || saved == null) return;
      context.showToast(
        tone: DesignSystemToastTone.success,
        title: messages.saveSuccessful,
      );
      beamToNamed(_listUrl);
    }

    final dirty =
        state.hasChanges ||
        (widget.isCreateMode && state.term.trim().isNotEmpty);
    final saveEnabled =
        !state.isSaving && state.term.trim().isNotEmpty && dirty;
    final errorText = _errorText(state.error, messages);

    return SaveShortcutScope(
      onSave: () {
        if (saveEnabled) handleSave();
      },
      isEnabled: () => saveEnabled,
      child: SettingsDetailScaffold(
        title: widget.isCreateMode
            ? messages.settingsSpeechDictionaryCreateTitle
            : messages.settingsSpeechDictionaryEditTitle,
        onBack: () => beamToNamed(_listUrl),
        actionBar: SettingsFormActionBar(
          primaryLabel: widget.isCreateMode
              ? messages.createButton
              : messages.saveButton,
          onPrimary: handleSave,
          primaryEnabled: saveEnabled,
          secondaryLabel: messages.cancelButton,
          onSecondary: () => beamToNamed(_listUrl),
        ),
        deleteLabel: widget.isCreateMode ? null : messages.deleteButton,
        onDelete: existing == null
            ? null
            : () => _confirmDelete(context, existing),
        deleteEnabled: !state.isSaving,
        children: [
          SettingsFormSection(
            title: messages.basicSettings,
            children: [
              DesignSystemTextInput(
                controller: _termController,
                label: messages.settingsSpeechDictionaryTermLabel,
                hintText: messages.settingsSpeechDictionaryTermHint,
                autofocus: widget.isCreateMode,
                onChanged: controller.setTerm,
              ),
            ],
          ),
          SettingsFormSection(
            title: messages.settingsSpeechDictionaryCategoriesHeading,
            description: messages.settingsSpeechDictionaryCategoriesDescription,
            children: [_buildCategories(context, state, controller)],
          ),
          SettingsFormSection(
            title: messages.settingsSpeechDictionaryMisheardHeading,
            description: messages.settingsSpeechDictionaryMisheardDescription,
            children: [
              DesignSystemTextarea(
                controller: _misheardController,
                semanticsLabel:
                    messages.settingsSpeechDictionaryMisheardHeading,
                hintText: messages.settingsSpeechDictionaryMisheardHint,
                onChanged: (text) =>
                    controller.setMisheardAs(parseSpeechTerms(text)),
                minLines: 2,
                maxLines: 4,
              ),
            ],
          ),
          if (errorText != null)
            Padding(
              padding: EdgeInsets.only(bottom: tokens.spacing.step4),
              child: Text(
                errorText,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.alert.error.ink,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String? _errorText(
    SpeechDictionaryEditorError? error,
    AppLocalizations messages,
  ) => switch (error) {
    null => null,
    SpeechDictionaryEditorError.emptyTerm =>
      messages.settingsSpeechDictionaryErrorEmpty,
    SpeechDictionaryEditorError.termTooLong => messages.addToDictionaryTooLong,
    SpeechDictionaryEditorError.duplicate => messages.addToDictionaryDuplicate,
  };

  Widget _buildCategories(
    BuildContext context,
    SpeechDictionaryEditorState state,
    SpeechDictionaryEditorController controller,
  ) {
    final tokens = context.designTokens;
    final cache = ref.watch(entitiesCacheServiceProvider);
    final categories =
        state.categoryIds
            .map((id) => cache?.getCategoryById(id))
            .whereType<CategoryDefinition>()
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (categories.isEmpty)
          Text(
            context.messages.settingsSpeechDictionaryAllCategories,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          )
        else
          Wrap(
            spacing: tokens.spacing.step2,
            runSpacing: tokens.spacing.step2,
            children: [
              for (final category in categories)
                CategorySelectionChip(
                  name: category.name,
                  color: colorFromCssHex(
                    category.color,
                    substitute: Theme.of(context).colorScheme.primary,
                  ),
                  onRemove: () => controller.removeCategoryId(category.id),
                  removeTooltip:
                      context.messages.settingsLabelsCategoriesRemoveTooltip,
                ),
            ],
          ),
        SizedBox(height: tokens.spacing.step3),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: DesignSystemButton(
            label: context.messages.settingsSpeechDictionaryCategoriesChoose,
            leadingIcon: LottiIcons.add,
            variant: DesignSystemButtonVariant.secondary,
            onPressed: () async {
              final result = await showCategoryMultiPicker(
                context: context,
                title:
                    context.messages.settingsSpeechDictionaryCategoriesChoose,
                initialSelectedIds: state.categoryIds,
              );
              if (result == null) return;
              controller.setCategoryIds(result.ids);
            },
          ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext pageContext, SpeechDictionaryEntry entry) {
    showDialog<bool>(
      context: pageContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          dialogContext.messages.settingsSpeechDictionaryDeleteConfirmTitle,
        ),
        content: Text(
          dialogContext.messages.settingsSpeechDictionaryDeleteConfirmMessage(
            entry.term,
          ),
        ),
        actions: [
          DesignSystemButton(
            label: dialogContext.messages.cancelButton,
            variant: DesignSystemButtonVariant.secondary,
            onPressed: () => Navigator.pop(dialogContext),
          ),
          DesignSystemButton(
            variant: DesignSystemButtonVariant.danger,
            label: dialogContext.messages.deleteButton,
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref
                  .read(speechDictionaryRepositoryProvider)
                  .delete(entry.id);
              if (!mounted || !pageContext.mounted) return;
              beamToNamed(_listUrl);
              pageContext.showToast(
                tone: DesignSystemToastTone.success,
                title: pageContext.messages
                    .settingsSpeechDictionaryDeleteSuccess(entry.term),
              );
            },
          ),
        ],
      ),
    );
  }
}
