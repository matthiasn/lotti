import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

extension InputDataTypeExtensions on InputDataType {
  String displayName(BuildContext context) {
    switch (this) {
      case InputDataType.task:
        return context.messages.inputDataTypeTaskName;
      case InputDataType.tasksList:
        return context.messages.inputDataTypeTasksListName;
      case InputDataType.audioFiles:
        return context.messages.inputDataTypeAudioFilesName;
      case InputDataType.images:
        return context.messages.inputDataTypeImagesName;
    }
  }

  String description(BuildContext context) {
    switch (this) {
      case InputDataType.task:
        return context.messages.inputDataTypeTaskDescription;
      case InputDataType.tasksList:
        return context.messages.inputDataTypeTasksListDescription;
      case InputDataType.audioFiles:
        return context.messages.inputDataTypeAudioFilesDescription;
      case InputDataType.images:
        return context.messages.inputDataTypeImagesDescription;
    }
  }
}
