import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/inference_model_form_state.dart';
import 'package:lotti/features/ai/model/inference_provider_form_state.dart';
import 'package:lotti/features/ai/ui/settings/widgets/form_components/form_error_extension.dart';

void main() {
  group('ModelFormErrorExtension.displayMessage', () {
    // Exhaustive over the enum: a newly added case must be mapped here
    // explicitly, otherwise this test fails instead of the form silently
    // showing nothing at runtime.
    const expected = {
      ModelFormError.tooShort: 'Must be at least 3 characters',
      ModelFormError.invalidNumber: 'Please enter a valid number',
    };

    test('maps every error to its user-facing message', () {
      for (final error in ModelFormError.values) {
        expect(error.displayMessage, expected[error], reason: '$error');
      }
    });
  });

  group('ProviderFormErrorExtension.displayMessage', () {
    const expected = {
      ProviderFormError.tooShort: 'Must be at least 3 characters',
      ProviderFormError.empty: 'This field is required',
      ProviderFormError.invalidUrl: 'Please enter a valid URL',
    };

    test('maps every error to its user-facing message', () {
      for (final error in ProviderFormError.values) {
        expect(error.displayMessage, expected[error], reason: '$error');
      }
    });
  });
}
