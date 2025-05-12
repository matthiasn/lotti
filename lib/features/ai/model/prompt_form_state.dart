import 'package:formz/formz.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/utils/file_utils.dart';

enum PromptFormError {
  tooShort,
  empty,
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

class PromptTemplate extends FormzInput<String, PromptFormError> {
  const PromptTemplate.pure() : super.pure('');
  const PromptTemplate.dirty([super.value = '']) : super.dirty();

  @override
  PromptFormError? validator(String value) {
    return value.isEmpty ? PromptFormError.empty : null;
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

// Form state class
class PromptFormState with FormzMixin {
  PromptFormState({
    this.id,
    this.name = const PromptName.pure(),
    this.template = const PromptTemplate.pure(),
    this.modelId = '',
    this.useReasoning = false,
    this.requiredInputData = const [],
    this.comment = const PromptComment.pure(),
    this.description = const PromptDescription.pure(),
    this.category = const PromptCategory.pure(),
    this.defaultVariables = const {},
    this.isSubmitting = false,
    this.submitFailed = false,
  });

  final String? id; // null for new prompts
  final PromptName name;
  final PromptTemplate template;
  final String modelId;
  final bool useReasoning;
  final List<InputDataType> requiredInputData;
  final PromptComment comment;
  final PromptDescription description;
  final PromptCategory category;
  final Map<String, String> defaultVariables;
  final bool isSubmitting;
  final bool submitFailed;

  PromptFormState copyWith({
    String? id,
    PromptName? name,
    PromptTemplate? template,
    String? modelId,
    bool? useReasoning,
    List<InputDataType>? requiredInputData,
    PromptComment? comment,
    PromptDescription? description,
    PromptCategory? category,
    Map<String, String>? defaultVariables,
    bool? isSubmitting,
    bool? submitFailed,
  }) {
    return PromptFormState(
      id: id ?? this.id,
      name: name ?? this.name,
      template: template ?? this.template,
      modelId: modelId ?? this.modelId,
      useReasoning: useReasoning ?? this.useReasoning,
      requiredInputData: requiredInputData ?? this.requiredInputData,
      comment: comment ?? this.comment,
      description: description ?? this.description,
      category: category ?? this.category,
      defaultVariables: defaultVariables ?? this.defaultVariables,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitFailed: submitFailed ?? this.submitFailed,
    );
  }

  @override
  List<FormzInput<dynamic, dynamic>> get inputs => [
        name,
        template,
        comment,
        description,
        category,
      ];

  // Convert form state to AiConfig model
  AiConfig toAiConfig() {
    return AiConfig.prompt(
      id: id ?? uuid.v1(),
      name: name.value,
      template: template.value,
      modelId: modelId,
      createdAt: DateTime.now(),
      useReasoning: useReasoning,
      requiredInputData: requiredInputData,
      comment: comment.value.isEmpty ? null : comment.value,
      description: description.value.isEmpty ? null : description.value,
      category: category.value.isEmpty ? null : category.value,
      defaultVariables: defaultVariables.isEmpty ? null : defaultVariables,
    );
  }
}
