import 'package:collection/collection.dart';
import 'package:lotti/features/front_agent/model/front_entity_preview.dart';
import 'package:meta/meta.dart';

/// What a turn's own lookups made that her reply can place among its parts:
/// the app fills each from the lookup's result, never from her words.
enum FrontReplyAttachment {
  /// The cards of every task a `list_closed_tasks` found.
  closedTasks('closed_tasks'),

  /// The chart of a `summarize_logged_time` that found time.
  loggedTimeChart('logged_time_chart'),

  /// The charts of a `summarize_pull_requests` that found some opened.
  pullRequestChart('pull_request_chart');

  const FrontReplyAttachment(this.wireName);

  final String wireName;

  static FrontReplyAttachment? fromWireName(Object? name) =>
      values.firstWhereOrNull((a) => a.wireName == name);
}

/// One part of her reply, in the order the user sees them: her words, a
/// list of cards, or something a lookup made. The parts are the catalog she
/// composes a reply from; which tasks, and which charts, the app checks
/// before anything is stored.
@immutable
sealed class FrontReplyPart {
  const FrontReplyPart();

  Map<String, Object?> toJson();

  /// Reads a part a reply stored; null for a shape this build does not
  /// know, such as a part a newer build added.
  static FrontReplyPart? fromJson(Object? json) {
    if (json is! Map) return null;
    if (json['text'] case final String text when text.trim().isNotEmpty) {
      return FrontReplyText(text);
    }
    if (json['cards'] case final List<Object?> cards) {
      final references = FrontEntityReference.listFromJson(cards);
      return references.isEmpty ? null : FrontReplyCards(references);
    }
    final attachment = FrontReplyAttachment.fromWireName(json['show']);
    return attachment == null ? null : FrontReplyShow(attachment);
  }

  /// Reads a stored list, skipping what [fromJson] does not know.
  static List<FrontReplyPart> listFromJson(Object? json) => [
    if (json is List)
      for (final item in json) ?fromJson(item),
  ];
}

/// Her words, as the Markdown she wrote them in.
class FrontReplyText extends FrontReplyPart {
  const FrontReplyText(this.markdown);

  final String markdown;

  @override
  Map<String, Object?> toJson() => {'text': markdown};

  @override
  bool operator ==(Object other) =>
      other is FrontReplyText && other.markdown == markdown;

  @override
  int get hashCode => markdown.hashCode;

  @override
  String toString() => 'FrontReplyText($markdown)';
}

/// Tasks and projects drawn as preview cards, in order.
class FrontReplyCards extends FrontReplyPart {
  const FrontReplyCards(this.cards);

  final List<FrontEntityReference> cards;

  @override
  Map<String, Object?> toJson() => {
    'cards': [for (final card in cards) card.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      other is FrontReplyCards &&
      const ListEquality<FrontEntityReference>().equals(other.cards, cards);

  @override
  int get hashCode => Object.hashAll(cards);

  @override
  String toString() => 'FrontReplyCards($cards)';
}

/// Where something a lookup made is drawn.
class FrontReplyShow extends FrontReplyPart {
  const FrontReplyShow(this.attachment);

  final FrontReplyAttachment attachment;

  @override
  Map<String, Object?> toJson() => {'show': attachment.wireName};

  @override
  bool operator ==(Object other) =>
      other is FrontReplyShow && other.attachment == attachment;

  @override
  int get hashCode => attachment.hashCode;

  @override
  String toString() => 'FrontReplyShow(${attachment.wireName})';
}
