import 'package:intl/intl.dart';

final _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');
final _timestampFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

/// Formats a [DateTime] as `yyyy-MM-dd HH:mm` for agent UI display.
///
/// Use this for date fields in the agent detail page (state info section)
/// where second-level precision is unnecessary.
String formatAgentDateTime(DateTime dt) => _dateTimeFormat.format(dt);

/// Formats a [DateTime] as `yyyy-MM-dd HH:mm:ss` for agent activity logs.
///
/// Use this for message timestamps in the activity log where second-level
/// precision helps distinguish rapid events.
String formatAgentTimestamp(DateTime dt) => _timestampFormat.format(dt);
