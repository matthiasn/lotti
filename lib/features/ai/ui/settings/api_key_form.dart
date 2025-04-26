import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formz/formz.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/themes/theme.dart';

// Input validation classes
class ApiKeyName extends FormzInput<String, String> {
  const ApiKeyName.pure() : super.pure('');
  const ApiKeyName.dirty([super.value = '']) : super.dirty();

  @override
  String? validator(String value) {
    return value.length < 3 ? 'Name must be at least 3 characters' : null;
  }
}

class ApiKeyValue extends FormzInput<String, String> {
  const ApiKeyValue.pure() : super.pure('');
  const ApiKeyValue.dirty([super.value = '']) : super.dirty();

  @override
  String? validator(String value) {
    return value.isEmpty ? 'API key cannot be empty' : null;
  }
}

class BaseUrl extends FormzInput<String, String> {
  const BaseUrl.pure() : super.pure('');
  const BaseUrl.dirty([super.value = '']) : super.dirty();

  @override
  String? validator(String value) {
    // Simple URL validation
    try {
      final uri = Uri.parse(value);
      if (!uri.isAbsolute ||
          (!uri.scheme.startsWith('http') && !uri.scheme.startsWith('https'))) {
        return 'Please enter a valid URL';
      }
      return null;
    } catch (_) {
      return 'Please enter a valid URL';
    }
  }
}

// Form state class
class ApiKeyFormState with FormzMixin {
  ApiKeyFormState({
    this.id,
    this.name = const ApiKeyName.pure(),
    this.apiKey = const ApiKeyValue.pure(),
    this.baseUrl = const BaseUrl.pure(),
    this.isSubmitting = false,
    this.submitFailed = false,
  });

  final String? id; // null for new API keys
  final ApiKeyName name;
  final ApiKeyValue apiKey;
  final BaseUrl baseUrl;
  final bool isSubmitting;
  final bool submitFailed;

  ApiKeyFormState copyWith({
    String? id,
    ApiKeyName? name,
    ApiKeyValue? apiKey,
    BaseUrl? baseUrl,
    bool? isSubmitting,
    bool? submitFailed,
  }) {
    return ApiKeyFormState(
      id: id ?? this.id,
      name: name ?? this.name,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitFailed: submitFailed ?? this.submitFailed,
    );
  }

  @override
  List<FormzInput<String, dynamic>> get inputs => [name, apiKey, baseUrl];

  // Convert form state to AiConfig model
  AiConfig toAiConfig() {
    return AiConfig.apiKey(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.value,
      apiKey: apiKey.value,
      baseUrl: baseUrl.value,
      createdAt: DateTime.now(),
    );
  }
}

// Provider to create the initial form state based on the config
final apiKeyFormInitialStateProvider =
    Provider.family<ApiKeyFormState, AiConfig?>((ref, config) {
  if (config == null) {
    return ApiKeyFormState();
  }

  // Extract fields from the config based on the pattern match
  var apiKeyValue = '';
  var baseUrlValue = '';

  // Check the specific type to access properties correctly
  config.maybeMap(
    apiKey: (apiKeyConfig) {
      apiKeyValue = apiKeyConfig.apiKey;
      baseUrlValue = apiKeyConfig.baseUrl;
    },
    orElse: () {},
  );

  return ApiKeyFormState(
    id: config.id,
    name: ApiKeyName.dirty(config.name),
    apiKey: ApiKeyValue.dirty(apiKeyValue),
    baseUrl: BaseUrl.dirty(baseUrlValue),
  );
});

// Form controller
class ApiKeyFormController extends StateNotifier<AsyncValue<ApiKeyFormState>> {
  ApiKeyFormController(ApiKeyFormState initialState)
      : super(AsyncData(initialState)) {
    _updateTextControllers(initialState);
  }

  final nameController = TextEditingController();
  final apiKeyController = TextEditingController();
  final baseUrlController = TextEditingController();

  void _updateTextControllers(ApiKeyFormState formState) {
    nameController.text = formState.name.value;
    apiKeyController.text = formState.apiKey.value;
    baseUrlController.text = formState.baseUrl.value;
  }

  void nameChanged(String value) {
    final name = ApiKeyName.dirty(value);
    state = AsyncData(
      state.valueOrNull!.copyWith(
        name: name,
      ),
    );
  }

  void apiKeyChanged(String value) {
    final apiKey = ApiKeyValue.dirty(value);
    state = AsyncData(
      state.valueOrNull!.copyWith(
        apiKey: apiKey,
      ),
    );
  }

  void baseUrlChanged(String value) {
    final baseUrl = BaseUrl.dirty(value);
    state = AsyncData(
      state.valueOrNull!.copyWith(
        baseUrl: baseUrl,
      ),
    );
  }

  void reset() {
    nameController.clear();
    apiKeyController.clear();
    baseUrlController.clear();
    state = AsyncData(ApiKeyFormState());
  }

  @override
  void dispose() {
    nameController.dispose();
    apiKeyController.dispose();
    baseUrlController.dispose();
    super.dispose();
  }
}

// Provider for the form controller with the config dependency
final apiKeyFormControllerProvider = StateNotifierProvider.family
    .autoDispose<ApiKeyFormController, AsyncValue<ApiKeyFormState>, AiConfig?>(
  (ref, config) {
    final initialState = ref.watch(apiKeyFormInitialStateProvider(config));
    return ApiKeyFormController(initialState);
  },
);

// The actual form widget
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
    // Use the family provider with the config directly - no need for initState now
    final formState =
        ref.watch(apiKeyFormControllerProvider(widget.config)).valueOrNull;
    final formController =
        ref.read(apiKeyFormControllerProvider(widget.config).notifier);

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
            ElevatedButton(
              onPressed: formState.isValid
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
