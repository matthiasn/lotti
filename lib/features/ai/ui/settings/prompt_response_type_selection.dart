import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/prompt_form_state.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/prompt_form_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/modals.dart';

class PromptResponseTypeSelection extends ConsumerWidget {
  const PromptResponseTypeSelection({super.key, this.configId});

  final String? configId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState =
        ref.watch(promptFormControllerProvider(configId: configId)).valueOrNull;
    final formController =
        ref.read(promptFormControllerProvider(configId: configId).notifier);

    if (formState == null) {
      return const SizedBox.shrink();
    }

    final selectedType = formState.aiResponseType.value;

    return InkWell(
      onTap: () async {
        final result = await ModalUtils.showSinglePageModal<AiResponseType>(
          context: context,
          builder: (modalContext) {
            return _ResponseTypeSelectionContent(
              title: context.messages.aiConfigSelectResponseTypeTitle,
              initialSelectedType: selectedType,
            );
          },
        );

        if (result != null) {
          formController.aiResponseTypeChanged(result);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: context.messages.aiConfigResponseTypeFieldLabel,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
          suffixIcon: const Icon(Icons.arrow_drop_down),
          errorText: formState.aiResponseType.isNotValid &&
                  // !formState.aiResponseType.isPure &&
                  formState.aiResponseType.error == PromptFormError.notSelected
              ? context.messages.aiConfigResponseTypeNotSelectedError
              : null,
        ),
        child: Text(
          selectedType?.localizedName(context) ??
              context.messages.aiConfigResponseTypeSelectHint,
          style: selectedType == null
              ? context.textTheme.bodyLarge?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                )
              : context.textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _ResponseTypeSelectionContent extends StatefulWidget {
  const _ResponseTypeSelectionContent({
    required this.title,
    this.initialSelectedType,
  });

  final String title;
  final AiResponseType? initialSelectedType;

  @override
  State<_ResponseTypeSelectionContent> createState() =>
      _ResponseTypeSelectionContentState();
}

class _ResponseTypeSelectionContentState
    extends State<_ResponseTypeSelectionContent> {
  late final ValueNotifier<AiResponseType?> _pageSelectedTypeNotifier;

  @override
  void initState() {
    super.initState();
    _pageSelectedTypeNotifier =
        ValueNotifier<AiResponseType?>(widget.initialSelectedType);
  }

  @override
  void dispose() {
    _pageSelectedTypeNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surface.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: context.colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Modal header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: context.colorScheme.outline.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: context.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.colorScheme.onSurface.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: context.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          
          // Response type options
          Flexible(
            child: ValueListenableBuilder<AiResponseType?>(
              valueListenable: _pageSelectedTypeNotifier,
              builder: (
                BuildContext listContext,
                AiResponseType? groupValue,
                Widget? child,
              ) {
                return ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: AiResponseType.values.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (BuildContext itemBuilderContext, int index) {
                    final type = AiResponseType.values[index];
                    final isSelected = type == groupValue;
                    
                    return Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? context.colorScheme.primaryContainer.withValues(alpha: 0.3)
                            : context.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? context.colorScheme.primary
                              : context.colorScheme.outline.withValues(alpha: 0.2),
                          width: 2, // Keep consistent border width to prevent breathing
                        ),
                      ),
                      child: RadioListTile<AiResponseType>(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        title: Text(
                          type.localizedName(itemBuilderContext),
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? context.colorScheme.primary
                                : context.colorScheme.onSurface,
                          ),
                        ),
                        value: type,
                        groupValue: groupValue,
                        activeColor: context.colorScheme.primary,
                        onChanged: (AiResponseType? value) {
                          _pageSelectedTypeNotifier.value = value;
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Save button
          Container(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              child: ValueListenableBuilder<AiResponseType?>(
                valueListenable: _pageSelectedTypeNotifier,
                builder: (
                  BuildContext btnContext,
                  AiResponseType? currentSelection,
                  Widget? child,
                ) {
                  return ElevatedButton.icon(
                    onPressed: currentSelection != null
                        ? () => Navigator.of(context).pop(currentSelection)
                        : null,
                    icon: const Icon(Icons.check_rounded, size: 20),
                    label: Text(
                      context.messages.saveButtonLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colorScheme.primary,
                      foregroundColor: context.colorScheme.onPrimary,
                      disabledBackgroundColor: context.colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
