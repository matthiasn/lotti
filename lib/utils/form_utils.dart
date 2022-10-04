import 'package:flutter/material.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

FormFieldValidator<String> numericValidator({
  String? errorText,
}) =>
    (valueCandidate) => true == valueCandidate?.isNotEmpty &&
            null == num.tryParse('$valueCandidate'.replaceAll(',', '.'))
        ? errorText ?? FormBuilderLocalizations.current.numericErrorText
        : null;
