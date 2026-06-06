import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/modality_extensions.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../widget_test_utils.dart';

void main() {
  testWidgets(
    'every modality resolves a distinct localized name and description',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        makeTestableWidget(
          Builder(
            builder: (c) {
              context = c;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(Modality.text.displayName(context), 'Text');
      expect(Modality.audio.displayName(context), 'Audio');
      expect(Modality.image.displayName(context), 'Image');

      expect(
        Modality.text.description(context),
        context.messages.modalityTextDescription,
      );
      expect(
        Modality.audio.description(context),
        context.messages.modalityAudioDescription,
      );
      expect(
        Modality.image.description(context),
        context.messages.modalityImageDescription,
      );

      // Names and descriptions are distinct, non-empty strings per modality.
      final names = Modality.values.map((m) => m.displayName(context)).toSet();
      final descriptions = Modality.values
          .map((m) => m.description(context))
          .toSet();
      expect(names, hasLength(Modality.values.length));
      expect(descriptions, hasLength(Modality.values.length));
      expect(names.any((n) => n.isEmpty), isFalse);
      expect(descriptions.any((d) => d.isEmpty), isFalse);
    },
  );
}
