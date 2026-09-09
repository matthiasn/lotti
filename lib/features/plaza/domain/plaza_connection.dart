import 'package:lotti/classes/entry_link.dart';
import 'package:meta/meta.dart';

/// One visible task relationship, retaining its stored semantic direction.
/// Plain associations are symmetric; typed relationships read from → to.
@immutable
class PlazaConnection {
  const PlazaConnection({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.type,
  });

  final String id;
  final String fromId;
  final String toId;
  final EntryLinkType type;

  bool get isDirected => type != EntryLinkType.basic;

  /// The connected task from either end; unrelated tasks have no destination.
  String? otherId(String taskId) => taskId == fromId
      ? toId
      : taskId == toId
      ? fromId
      : null;
}
