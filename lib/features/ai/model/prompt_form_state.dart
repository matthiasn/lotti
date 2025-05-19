import 'package:formz/formz.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/utils/file_utils.dart';

enum PromptFormError {
  tooShort,
  empty,
  notSelected,
}

// Input validation classes
class PromptName extends FormzInput<String, PromptFormError> {
  const PromptName.pure() : super.pure('');
  const PromptName.dirty([super.value = '']) : super.dirty();

  @override
  PromptFormError? validator(String value) {
    return value.length < 3 ? PromptFormError.tooShort : null;
  }
}

class PromptUserMessage extends FormzInput<String, PromptFormError> {
  const PromptUserMessage.pure() : super.pure('');
  const PromptUserMessage.dirty([super.value = '']) : super.dirty();

  @override
  PromptFormError? validator(String value) {
    return value.isEmpty ? PromptFormError.empty : null;
  }
}

class PromptSystemMessage extends FormzInput<String, PromptFormError> {
  const PromptSystemMessage.pure() : super.pure('');
  const PromptSystemMessage.dirty([super.value = '']) : super.dirty();

  @override
  PromptFormError? validator(String value) {
    return null;
  }
}

class PromptDescription extends FormzInput<String, PromptFormError> {
  const PromptDescription.pure() : super.pure('');
  const PromptDescription.dirty([super.value = '']) : super.dirty();

  @override
  PromptFormError? validator(String value) {
    return null; // Optional field
  }
}

class PromptComment extends FormzInput<String, PromptFormError> {
  const PromptComment.pure() : super.pure('');
  const PromptComment.dirty([super.value = '']) : super.dirty();

  @override
  PromptFormError? validator(String value) {
    return null; // Optional field
  }
}

class PromptCategory extends FormzInput<String, PromptFormError> {
  const PromptCategory.pure() : super.pure('');
  const PromptCategory.dirty([super.value = '']) : super.dirty();

  @override
  PromptFormError? validator(String value) {
    return null; // Optional field
  }
}

class PromptAiResponseType
    extends FormzInput<AiResponseType?, PromptFormError> {
  const PromptAiResponseType.pure() : super.pure(null);
  const PromptAiResponseType.dirty([super.value]) : super.dirty();

  @override
  PromptFormError? validator(AiResponseType? value) {
    return value == null ? PromptFormError.notSelected : null;
  }
}

// Form state class
class PromptFormState with FormzMixin {
  PromptFormState({
    this.id,
    this.name = const PromptName.pure(),
    this.systemMessage = const PromptSystemMessage.pure(),
    this.userMessage = const PromptUserMessage.pure(),
    this.defaultModelId = '',
    this.modelIds = const [],
    this.useReasoning = false,
    this.requiredInputData = const [],
    this.comment = const PromptComment.pure(),
    this.description = const PromptDescription.pure(),
    this.category = const PromptCategory.pure(),
    this.defaultVariables = const {},
    this.isSubmitting = false,
    this.submitFailed = false,
    this.aiResponseType = const PromptAiResponseType.pure(),
  });

  final String? id; // null for new prompts
  final PromptName name;
  final PromptUserMessage userMessage;
  final PromptSystemMessage systemMessage;
  final String defaultModelId;
  final List<String> modelIds;
  final bool useReasoning;
  final List<InputDataType> requiredInputData;
  final PromptComment comment;
  final PromptDescription description;
  final PromptCategory category;
  final Map<String, String> defaultVariables;
  final bool isSubmitting;
  final bool submitFailed;
  final PromptAiResponseType aiResponseType;

  PromptFormState copyWith({
    String? id,
    PromptName? name,
    PromptSystemMessage? systemMessage,
    PromptUserMessage? userMessage,
    String? defaultModelId,
    List<String>? modelIds,
    bool? useReasoning,
    List<InputDataType>? requiredInputData,
    PromptComment? comment,
    PromptDescription? description,
    PromptCategory? category,
    Map<String, String>? defaultVariables,
    bool? isSubmitting,
    bool? submitFailed,
    PromptAiResponseType? aiResponseType,
  }) {
    return PromptFormState(
      id: id ?? this.id,
      name: name ?? this.name,
      systemMessage: systemMessage ?? this.systemMessage,
      userMessage: userMessage ?? this.userMessage,
      defaultModelId: defaultModelId ?? this.defaultModelId,
      modelIds: modelIds ?? this.modelIds,
      useReasoning: useReasoning ?? this.useReasoning,
      requiredInputData: requiredInputData ?? this.requiredInputData,
      comment: comment ?? this.comment,
      description: description ?? this.description,
      category: category ?? this.category,
      defaultVariables: defaultVariables ?? this.defaultVariables,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitFailed: submitFailed ?? this.submitFailed,
      aiResponseType: aiResponseType ?? this.aiResponseType,
    );
  }

  @override
  List<FormzInput<dynamic, dynamic>> get inputs => [
        name,
        userMessage,
        systemMessage,
        comment,
        description,
        category,
        aiResponseType,
      ];

  // Convert form state to AiConfig model
  AiConfig toAiConfig() {
    if (aiResponseType.value == null) {
      throw StateError('AiResponseType cannot be null when creating AiConfig');
    }
    return AiConfig.prompt(
      id: id ?? uuid.v1(),
      name: name.value,
      systemMessage: systemMessage.value,
      userMessage: userMessage.value,
      defaultModelId: defaultModelId,
      modelIds: modelIds,
      createdAt: DateTime.now(),
      updatedAt: id != null ? DateTime.now() : null,
      useReasoning: useReasoning,
      requiredInputData: requiredInputData,
      aiResponseType: aiResponseType.value!,
      comment: comment.value.isEmpty ? null : comment.value,
      description: description.value.isEmpty ? null : description.value,
      category: category.value.isEmpty ? null : category.value,
      defaultVariables: defaultVariables.isEmpty ? null : defaultVariables,
    );
  }
}
