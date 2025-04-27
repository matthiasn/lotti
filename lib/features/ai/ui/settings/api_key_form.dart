import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/api_key_form_controller.dart';
import 'package:lotti/themes/theme.dart';

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
          child: TextField(
            onChanged: formController.nameChanged,
            controller: formController.nameController,
            decoration: InputDecoration(
              labelText: 'Name',
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
              labelText: 'Base URL',
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
              labelText: 'API Key',
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
        SizedBox(
          height: 100,
          child: TextField(
            onChanged: formController.commentChanged,
            controller: formController.commentController,
            decoration: const InputDecoration(
              labelText: 'Comment (Optional)',
            ),
            maxLines: 2,
          ),
        ),
        SizedBox(
          height: 50,
          child: formState.submitFailed
              ? Text(
                  'Failed to save API key configuration',
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
              child: Text(widget.config == null ? 'Create' : 'Update'),
            ),
          ],
        ),
      ],
    );
  }
}
