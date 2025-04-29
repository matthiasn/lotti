import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_provider_extensions.dart';
import 'package:lotti/features/ai/state/api_key_form_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/modals.dart';

class ApiKeyForm extends ConsumerStatefulWidget {
  const ApiKeyForm({
    required this.onSave,
    this.config,
    super.key,
  });

  final AiConfig? config;
  final void Function(AiConfig) onSave;

  @override
  ConsumerState<ApiKeyForm> createState() => _ApiKeyFormState();
}

class _ApiKeyFormState extends ConsumerState<ApiKeyForm> {
  bool _showApiKey = false;

  void _showProviderTypeModal() {
    ModalUtils.showSinglePageModal<void>(
      context: context,
      title: context.messages.aiConfigSelectProviderTypeModalTitle,
      builder: (modalContext) {
        final formState = ref
            .watch(
              apiKeyFormControllerProvider(configId: widget.config?.id),
            )
            .valueOrNull;
        final formController = ref.read(
          apiKeyFormControllerProvider(configId: widget.config?.id).notifier,
        );

        if (formState == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          shrinkWrap: true,
          children: InferenceProviderType.values.map((type) {
            return ListTile(
              title: Text(type.displayName(modalContext)),
              subtitle: Text(type.description(modalContext)),
              leading: Icon(type.icon),
              trailing: formState.inferenceProviderType == type
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                formController.inferenceProviderTypeChanged(type);
                Navigator.of(modalContext).pop();
              },
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final configId = widget.config?.id;
    final formState =
        ref.watch(apiKeyFormControllerProvider(configId: configId)).valueOrNull;
    final formController =
        ref.read(apiKeyFormControllerProvider(configId: configId).notifier);

    if (formState == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: 90,
          child: InkWell(
            onTap: _showProviderTypeModal,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: context.messages.aiConfigProviderTypeFieldLabel,
                suffixIcon: const Icon(Icons.arrow_drop_down),
              ),
              child: Row(
                children: [
                  Icon(formState.inferenceProviderType.icon, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      formState.inferenceProviderType.displayName(context),
                      style: context.textTheme.bodyLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          height: 90,
          child: TextField(
            onChanged: formController.nameChanged,
            controller: formController.nameController,
            decoration: InputDecoration(
              labelText: context.messages.aiConfigNameFieldLabel,
              errorText: formState.name.isNotValid && !formState.name.isPure
                  ? formState.name.error
                  : null,
            ),
          ),
        ),
        SizedBox(
          height: 90,
          child: TextField(
            onChanged: formController.baseUrlChanged,
            controller: formController.baseUrlController,
            decoration: InputDecoration(
              labelText: context.messages.aiConfigBaseUrlFieldLabel,
              errorText:
                  formState.baseUrl.isNotValid && !formState.baseUrl.isPure
                      ? formState.baseUrl.error
                      : null,
            ),
          ),
        ),
        SizedBox(
          height: 90,
          child: TextField(
            onChanged: formController.apiKeyChanged,
            controller: formController.apiKeyController,
            obscureText: !_showApiKey,
            decoration: InputDecoration(
              labelText: context.messages.aiConfigApiKeyFieldLabel,
              errorText: formState.apiKey.isNotValid && !formState.apiKey.isPure
                  ? formState.apiKey.error
                  : null,
              suffixIcon: IconButton(
                icon: Icon(
                  _showApiKey
                      ? Icons.remove_red_eye_outlined
                      : Icons.remove_red_eye,
                  color: context.colorScheme.outline,
                  semanticLabel: 'Show API Key',
                ),
                onPressed: () => setState(() {
                  _showApiKey = !_showApiKey;
                }),
              ),
            ),
          ),
        ),
        TextField(
          onChanged: formController.commentChanged,
          controller: formController.commentController,
          decoration: InputDecoration(
            labelText: context.messages.aiConfigCommentFieldLabel,
          ),
          maxLines: 3,
        ),
        SizedBox(
          height: 50,
          child: formState.submitFailed
              ? Text(
                  context.messages.aiConfigFailedToSaveMessage,
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: context.colorScheme.error,
                  ),
                )
              : null,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FilledButton(
              onPressed: formState.isValid &&
                      (widget.config == null || formState.isDirty)
                  ? () {
                      final config = formState.toAiConfig();
                      widget.onSave(config);
                    }
                  : null,
              child: Text(
                widget.config == null
                    ? context.messages.aiConfigCreateButtonLabel
                    : context.messages.aiConfigUpdateButtonLabel,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
