import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/api_key_form_state.dart';

// Provider to create the initial form state based on the config
final apiKeyFormInitialStateProvider =
    Provider.family<ApiKeyFormState, AiConfig?>((ref, config) {
  if (config == null) {
    return ApiKeyFormState();
  }

  // Extract fields from the config based on the pattern match
  var apiKeyValue = '';
  var baseUrlValue = '';
  var commentValue = '';

  // Check the specific type to access properties correctly
  config.maybeMap(
    apiKey: (apiKeyConfig) {
      apiKeyValue = apiKeyConfig.apiKey;
      baseUrlValue = apiKeyConfig.baseUrl;
      commentValue = apiKeyConfig.comment ?? '';
    },
    orElse: () {},
  );

  return ApiKeyFormState(
    id: config.id,
    name: ApiKeyName.dirty(config.name),
    apiKey: ApiKeyValue.dirty(apiKeyValue),
    baseUrl: BaseUrl.dirty(baseUrlValue),
    comment: CommentValue.dirty(commentValue),
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
  final commentController = TextEditingController();

  void _updateTextControllers(ApiKeyFormState formState) {
    nameController.text = formState.name.value;
    apiKeyController.text = formState.apiKey.value;
    baseUrlController.text = formState.baseUrl.value;
    commentController.text = formState.comment.value;
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

  void commentChanged(String value) {
    final comment = CommentValue.dirty(value);
    state = AsyncData(
      state.valueOrNull!.copyWith(
        comment: comment,
      ),
    );
  }

  void reset() {
    nameController.clear();
    apiKeyController.clear();
    baseUrlController.clear();
    commentController.clear();
    state = AsyncData(ApiKeyFormState());
  }

  @override
  void dispose() {
    nameController.dispose();
    apiKeyController.dispose();
    baseUrlController.dispose();
    commentController.dispose();
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
