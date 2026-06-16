import 'package:lotti/features/ai/model/inference_model_form_state.dart';
import 'package:lotti/features/ai/model/inference_provider_form_state.dart';

/// Maps each [ModelFormError] variant to the human-readable validation message
/// shown beneath the offending model-form field.
extension ModelFormErrorExtension on ModelFormError {
  /// English copy for this validation error. Not localized — these strings
  /// are surfaced directly by the model edit form's inline error rows.
  String get displayMessage {
    switch (this) {
      case ModelFormError.tooShort:
        return 'Must be at least 3 characters';
      case ModelFormError.invalidNumber:
        return 'Please enter a valid number';
    }
  }
}

/// Maps each [ProviderFormError] variant to the human-readable validation
/// message shown beneath the offending provider-form field.
extension ProviderFormErrorExtension on ProviderFormError {
  /// English copy for this validation error. Not localized — these strings
  /// are surfaced directly by the provider edit form's inline error rows.
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
