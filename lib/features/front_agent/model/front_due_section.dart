import 'package:lotti/features/front_agent/model/front_routing_index.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:meta/meta.dart';

/// What a reply's list of due tasks is: the window `list_due_tasks` read —
/// due today, overdue, or due through a later day — kept on her reply so the
/// list is drawn under a quiet label saying so. The label comes from what
/// was asked and read, never from her words, which have no headings: they
/// may be read aloud.
@immutable
class FrontDueSection {
  const FrontDueSection({
    required this.window,
    required this.today,
    required this.through,
  });

  final FrontDueWindow window;

  /// The day the question was asked on, at local midnight.
  final DateTime today;

  /// The last day the window reaches, at local midnight: [today] for
  /// `today` and `overdue`.
  final DateTime through;

  /// Whether the window ends on the day it was asked: nothing later is in
  /// it.
  bool get endsToday => !through.isAfter(today);

  Map<String, Object> toJson() => {
    'window': window.name,
    'today': today.ymd,
    'through': through.ymd,
  };

  /// Reads a stored section; null for a shape this build does not know.
  static FrontDueSection? fromJson(Object? json) {
    if (json is! Map) return null;
    final window = FrontDueWindow.fromWire(json['window']);
    final today = DateTime.tryParse('${json['today']}');
    final through = DateTime.tryParse('${json['through']}');
    if (window == null || today == null || through == null) return null;
    return FrontDueSection(window: window, today: today, through: through);
  }

  @override
  bool operator ==(Object other) =>
      other is FrontDueSection &&
      other.window == window &&
      other.today == today &&
      other.through == through;

  @override
  int get hashCode => Object.hash(window, today, through);

  @override
  String toString() =>
      'FrontDueSection(${window.name}, ${today.ymd}–${through.ymd})';
}
