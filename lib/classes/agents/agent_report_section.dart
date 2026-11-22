import 'package:freezed_annotation/freezed_annotation.dart';

part 'agent_report_section.freezed.dart';
part 'agent_report_section.g.dart';

/// How a report section's body is shaped.
enum AgentReportSectionKind {
  /// A bulleted list of [AgentReportSection.items].
  points,

  /// A to-do list: each item is open or done.
  checklist,

  /// One paragraph in [AgentReportSection.text].
  text,
}

/// One section of a task agent's report, as the agent wrote it with
/// `update_report(sections:)`. Item and paragraph text is inline Markdown, so
/// links and emphasis survive; the block structure is data, not Markdown.
@freezed
abstract class AgentReportSection with _$AgentReportSection {
  const factory AgentReportSection({
    required AgentReportSectionKind kind,

    /// Heading in the task language; empty for an untitled lead paragraph.
    @Default('') String title,

    /// The paragraph of a [AgentReportSectionKind.text] section.
    @Default('') String text,

    /// The rows of a points or checklist section.
    @Default(<AgentReportSectionItem>[]) List<AgentReportSectionItem> items,
  }) = _AgentReportSection;

  factory AgentReportSection.fromJson(Map<String, dynamic> json) =>
      _$AgentReportSectionFromJson(json);
}

/// One row of a points or checklist section.
@freezed
abstract class AgentReportSectionItem with _$AgentReportSectionItem {
  const factory AgentReportSectionItem({
    required String text,

    /// Only meaningful in a checklist section.
    @Default(false) bool done,
  }) = _AgentReportSectionItem;

  factory AgentReportSectionItem.fromJson(Map<String, dynamic> json) =>
      _$AgentReportSectionItemFromJson(json);
}

/// Reads the model's `sections` argument, dropping anything malformed: an
/// unknown kind, a paragraph with no text, a list with no usable rows. Returns
/// an empty list when nothing usable remains.
List<AgentReportSection> parseAgentReportSections(Object? raw) {
  if (raw is! List) return const [];
  final sections = <AgentReportSection>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    final kind = AgentReportSectionKind.values
        .where((value) => value.name == entry['kind'])
        .firstOrNull;
    if (kind == null) continue;
    final title = _trimmed(entry['title']);
    if (kind == AgentReportSectionKind.text) {
      final text = _trimmed(entry['text']);
      if (text.isEmpty) continue;
      sections.add(AgentReportSection(kind: kind, title: title, text: text));
      continue;
    }
    final items = [
      for (final item in entry['items'] is List ? entry['items'] as List : [])
        if (item is Map && _trimmed(item['text']).isNotEmpty)
          AgentReportSectionItem(
            text: _trimmed(item['text']),
            done: item['done'] == true,
          )
        else if (item is String && item.trim().isNotEmpty)
          AgentReportSectionItem(text: item.trim()),
    ];
    if (items.isEmpty) continue;
    sections.add(AgentReportSection(kind: kind, title: title, items: items));
  }
  return sections;
}

/// The Markdown form of [sections], stored as the report's `content` so every
/// reader of the text (internals, search, read-aloud, the report checks) keeps
/// working unchanged.
String renderAgentReportSectionsMarkdown(List<AgentReportSection> sections) => [
  for (final section in sections)
    [
      if (section.title.isNotEmpty) '## ${section.title}',
      switch (section.kind) {
        AgentReportSectionKind.text => section.text,
        AgentReportSectionKind.points => [
          for (final item in section.items) '- ${item.text}',
        ].join('\n'),
        AgentReportSectionKind.checklist => [
          for (final item in section.items)
            '- [${item.done ? 'x' : ' '}] ${item.text}',
        ].join('\n'),
      },
    ].join('\n\n'),
].join('\n\n');

String _trimmed(Object? value) => value is String ? value.trim() : '';
