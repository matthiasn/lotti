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
          title: context.messages.aiConfigSelectResponseTypeTitle,
          builder: (modalContext) {
            return _ResponseTypeSelectionContent(
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
    this.initialSelectedType,
  });

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
    return Padding(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Flexible(
            child: ValueListenableBuilder<AiResponseType?>(
              valueListenable: _pageSelectedTypeNotifier,
              builder: (
                BuildContext listContext,
                AiResponseType? groupValue,
                Widget? child,
              ) {
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: AiResponseType.values.length,
                  itemBuilder: (BuildContext itemBuilderContext, int index) {
                    final type = AiResponseType.values[index];
                    return RadioListTile<AiResponseType>(
                      title: Text(type.localizedName(itemBuilderContext)),
                      value: type,
                      groupValue: groupValue,
                      onChanged: (AiResponseType? value) {
                        _pageSelectedTypeNotifier.value = value;
                      },
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ValueListenableBuilder<AiResponseType?>(
                valueListenable: _pageSelectedTypeNotifier,
                builder: (
                  BuildContext btnContext,
                  AiResponseType? currentSelection,
                  Widget? child,
                ) {
                  return FilledButton(
                    onPressed: currentSelection != null
                        ? () => Navigator.of(context).pop(currentSelection)
                        : null,
                    child: Text(context.messages.saveButtonLabel),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
