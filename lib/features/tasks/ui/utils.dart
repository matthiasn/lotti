import 'package:flutter/material.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

Color taskColorFromStatusString(String status) => switch (status) {
      'OPEN' => Colors.orange,
      'GROOMED' => Colors.lightGreenAccent,
      'IN PROGRESS' => Colors.blue,
      'BLOCKED' => Colors.red,
      'ON HOLD' => Colors.red,
      'DONE' => Colors.green,
      'REJECTED' => Colors.red,
      String() => Colors.grey,
    };

String taskLabelFromStatusString(
  String status,
  BuildContext context,
) =>
    switch (status) {
      'OPEN' => context.messages.taskStatusOpen,
      'GROOMED' => context.messages.taskStatusGroomed,
      'IN PROGRESS' => context.messages.taskStatusInProgress,
      'BLOCKED' => context.messages.taskStatusBlocked,
      'ON HOLD' => context.messages.taskStatusOnHold,
      'DONE' => context.messages.taskStatusDone,
      'REJECTED' => context.messages.taskStatusRejected,
      String() => '-',
    };

const allTaskStatuses = [
  'OPEN',
  'GROOMED',
  'IN PROGRESS',
  'BLOCKED',
  'ON HOLD',
  'DONE',
  'REJECTED',
];
