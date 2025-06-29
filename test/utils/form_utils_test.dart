import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:lotti/utils/form_utils.dart';

void main() {
  group('numericValidator', () {
    // We need a MaterialApp to provide FormBuilderLocalizations
    final widget = MaterialApp(
      localizationsDelegates: const [
        FormBuilderLocalizations.delegate,
      ],
      home: Scaffold(
        body: Builder(
          builder: (context) {
            // Trigger localization initialization
            FormBuilderLocalizations.of(context);
            return Container();
          },
        ),
      ),
    );

    testWidgets('should return null for valid numeric strings', (tester) async {
      await tester.pumpWidget(widget);
      final validator = numericValidator();
      expect(validator('123'), isNull);
      expect(validator('123.45'), isNull);
      expect(validator('-123'), isNull);
      expect(validator('0'), isNull);
    });

    testWidgets(
        'should return default error message for invalid numeric strings',
        (tester) async {
      await tester.pumpWidget(widget);
      final validator = numericValidator();
      final localizations =
          FormBuilderLocalizations.of(tester.element(find.byType(Container)));
      expect(validator('abc'), localizations.numericErrorText);
      expect(validator('12a'), localizations.numericErrorText);
    });

    testWidgets(
        'should return custom error message for invalid numeric strings',
        (tester) async {
      await tester.pumpWidget(widget);
      const customError = 'Custom error message';
      final validator = numericValidator(errorText: customError);
      expect(validator('abc'), customError);
    });

    testWidgets('should return null for empty or null strings', (tester) async {
      await tester.pumpWidget(widget);
      final validator = numericValidator();
      expect(validator(''), isNull);
      expect(validator(null), isNull);
    });
  });
}
