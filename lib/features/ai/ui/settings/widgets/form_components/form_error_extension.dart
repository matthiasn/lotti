import 'package:lotti/features/ai/model/inference_model_form_state.dart';
import 'package:lotti/features/ai/model/inference_provider_form_state.dart';
import 'package:lotti/features/ai/model/prompt_form_state.dart';

extension ModelFormErrorExtension on ModelFormError {
  String get displayMessage {
    switch (this) {
      case ModelFormError.tooShort:
        return 'Must be at least 3 characters';
      case ModelFormError.invalidNumber:
        return 'Please enter a valid number';
    }
  }
}

extension ProviderFormErrorExtension on ProviderFormError {
  String get displayMessage {
    switch (this) {
      case ProviderFormError.tooShort:
        return 'Must be at least 3 characters';
      case ProviderFormError.empty:
        return 'This field is required';
      case ProviderFormError.invalidUrl:
        return 'Please enter a valid URL';
    }
  }
}

extension PromptFormErrorExtension on PromptFormError {
  String get displayMessage {
    switch (this) {
      case PromptFormError.tooShort:
        return 'Must be at least 3 characters';
      case PromptFormError.empty:
        return 'This field is required';
      case PromptFormError.notSelected:
        return 'Please select an option';
    }
  }
}
