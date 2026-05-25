// Structured plan-adjacent models used by the Daily OS day-agent backend.

import 'package:meta/meta.dart';

/// Energy intensity shown behind the drafted day timeline.
enum DayAgentEnergyLevel {
  /// High-focus part of the day.
  high,

  /// Low-energy part of the day.
  low,

  /// Later recovery of focus.
  secondWind,
}

/// A timeline energy band emitted with a drafted plan.
@immutable
class DayAgentEnergyBand {
  /// Creates an energy band.
  const DayAgentEnergyBand({
    required this.start,
    required this.end,
    required this.level,
    required this.label,
  });

  /// Creates an energy band from JSON.
  factory DayAgentEnergyBand.fromJson(Map<String, dynamic> json) {
    return DayAgentEnergyBand(
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
      level: DayAgentEnergyLevel.values.byName(json['level'] as String),
      label: json['label'] as String,
    );
  }

  /// Band start.
  final DateTime start;

  /// Band end.
  final DateTime end;

  /// Energy level.
  final DayAgentEnergyLevel level;

  /// Display label.
  final String label;

  /// Converts this band to JSON.
  Map<String, Object?> toJson() => {
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'level': level.name,
    'label': label,
  };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DayAgentEnergyBand &&
            other.start == start &&
            other.end == end &&
            other.level == level &&
            other.label == label;
  }

  @override
  int get hashCode => Object.hash(start, end, level, label);
}

/// Tone for a learning-card bullet.
enum DayAgentLearningBulletTone {
  /// Neutral information.
  info,

  /// Positive reinforcement.
  positive,

  /// Warning or gentle caution.
  warning,
}

/// One bullet in a learning card.
@immutable
class DayAgentLearningBullet {
  /// Creates a bullet.
  const DayAgentLearningBullet({
    required this.text,
    required this.tone,
  });

  /// Creates a bullet from JSON.
  factory DayAgentLearningBullet.fromJson(Map<String, dynamic> json) {
    return DayAgentLearningBullet(
      text: json['text'] as String,
      tone: DayAgentLearningBulletTone.values.byName(json['tone'] as String),
    );
  }

  /// Bullet text.
  final String text;

  /// Bullet tone.
  final DayAgentLearningBulletTone tone;

  /// Converts this bullet to JSON.
  Map<String, Object?> toJson() => {
    'text': text,
    'tone': tone.name,
  };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DayAgentLearningBullet &&
            other.text == text &&
            other.tone == tone;
  }

  @override
  int get hashCode => Object.hash(text, tone);
}

/// Card shape returned by `summarize_recent_patterns`.
@immutable
class DayAgentLearningCard {
  /// Creates a learning card.
  const DayAgentLearningCard({
    required this.id,
    required this.overline,
    required this.summary,
    required this.bullets,
    this.kind = 'standard',
  });

  /// Creates a learning card from JSON.
  factory DayAgentLearningCard.fromJson(Map<String, dynamic> json) {
    return DayAgentLearningCard(
      id: json['id'] as String,
      overline: json['overline'] as String,
      summary: json['summary'] as String,
      bullets: [
        for (final bullet in json['bullets'] as List<dynamic>)
          DayAgentLearningBullet.fromJson(bullet as Map<String, dynamic>),
      ],
      kind: json['kind'] as String? ?? 'standard',
    );
  }

  /// Card id.
  final String id;

  /// Small section label.
  final String overline;

  /// Primary summary sentence.
  final String summary;

  /// Bullet details.
  final List<DayAgentLearningBullet> bullets;

  /// UI card kind, e.g. `standard` or `nudge`.
  final String kind;

  /// Converts this card to JSON.
  Map<String, Object?> toJson() => {
    'id': id,
    'overline': overline,
    'summary': summary,
    'bullets': [for (final bullet in bullets) bullet.toJson()],
    'kind': kind,
  };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DayAgentLearningCard &&
            other.id == id &&
            other.overline == overline &&
            other.summary == summary &&
            other.kind == kind &&
            _bulletListsEqual(other.bullets, bullets);
  }

  @override
  int get hashCode => Object.hash(
    id,
    overline,
    summary,
    Object.hashAll(bullets),
    kind,
  );

  static bool _bulletListsEqual(
    List<DayAgentLearningBullet> a,
    List<DayAgentLearningBullet> b,
  ) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}
