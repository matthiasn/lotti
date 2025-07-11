import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

extension ModalityExtension on Modality {
  String displayName(BuildContext context) {
    switch (this) {
      case Modality.text:
        return context.messages.modalityTextName;
      case Modality.audio:
        return context.messages.modalityAudioName;
      case Modality.image:
        return context.messages.modalityImageName;
    }
  }

  String description(BuildContext context) {
    switch (this) {
      case Modality.text:
        return context.messages.modalityTextDescription;
      case Modality.audio:
        return context.messages.modalityAudioDescription;
      case Modality.image:
        return context.messages.modalityImageDescription;
    }
  }
}
