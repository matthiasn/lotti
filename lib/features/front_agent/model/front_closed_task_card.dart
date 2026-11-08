import 'package:meta/meta.dart';

/// One task her reply to a "what did I complete?" question draws as a card
/// under her words: the task, how it closed — completed or [rejected] — and
/// when, and whether it has been [reopened] since. The reply stores every
/// task the `list_closed_tasks` call found, so the cards list them all
/// whatever she wrote.
@immutable
class FrontClosedTaskCard {
  const FrontClosedTaskCard({
    required this.id,
    required this.title,
    required this.closedAt,
    this.rejected = false,
    this.reopened = false,
    this.categoryId,
  });

  final String id;
  final String title;
  final DateTime closedAt;
  final bool rejected;

  /// The task is open again now: it closed in the window, then was reopened.
  final bool reopened;
  final String? categoryId;

  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'closedAt': closedAt.toUtc().toIso8601String(),
    if (rejected) 'rejected': true,
    if (reopened) 'reopened': true,
    'categoryId': ?categoryId,
  };

  /// Reads a stored card; null for a shape this build does not know.
  static FrontClosedTaskCard? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final title = json['title'];
    final closedAt = DateTime.tryParse('${json['closedAt']}');
    final categoryId = json['categoryId'];
    if (id is! String || title is! String || closedAt == null) return null;
    return FrontClosedTaskCard(
      id: id,
      title: title,
      closedAt: closedAt,
      rejected: json['rejected'] == true,
      reopened: json['reopened'] == true,
      categoryId: categoryId is String ? categoryId : null,
    );
  }

  /// Reads a stored list of cards, dropping any it does not know.
  static List<FrontClosedTaskCard> listFromJson(Object? json) => [
    if (json is List)
      for (final item in json) ?fromJson(item),
  ];

  @override
  bool operator ==(Object other) =>
      other is FrontClosedTaskCard &&
      other.id == id &&
      other.title == title &&
      other.closedAt.isAtSameMomentAs(closedAt) &&
      other.rejected == rejected &&
      other.reopened == reopened &&
      other.categoryId == categoryId;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    closedAt.millisecondsSinceEpoch,
    rejected,
    reopened,
    categoryId,
  );

  @override
  String toString() =>
      'FrontClosedTaskCard($id, ${rejected ? 'rejected' : 'completed'} '
      '${closedAt.toIso8601String()}${reopened ? ', reopened' : ''})';
}
