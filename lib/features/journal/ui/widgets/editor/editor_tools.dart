// Flutter Quill marks its clipboard customization API experimental, but it is
// the package's supported hook for preserving rich clipboard paste precedence.
// ignore_for_file: experimental_member_use

import 'dart:convert';
import 'dart:math' as math;

import 'package:delta_markdown/delta_markdown.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:lotti/classes/entry_text.dart';

final _markdownBlockPattern = RegExp(
  r'^(?: {0,3}#{1,3}[ \t]+| {0,3}>[ \t]?|'
  r' {0,3}(?:[-+*]|\d+[.)])[ \t]+| {0,3}(?:`{3,}|~{3,}))',
  multiLine: true,
);
final _markdownHorizontalRulePattern = RegExp(
  r'^ {0,3}(?:(?:\*[ \t]*){3,}|(?:_[ \t]*){3,}|(?:-[ \t]*){3,})$',
  multiLine: true,
);
final _markdownInlinePattern = RegExp(
  r'(?<!\\)(?:'
  r'\*\*(?=\S)(?:(?!\*\*).)+\*\*|'
  r'__(?=\S)(?:(?!__).)+__|'
  r'~~(?=\S)(?:(?!~~).)+~~|'
  r'\[[^\]\n]+\]\([^)\n]+\))',
);
final _markdownItalicPattern = RegExp(
  r'(?<![\w\\])[*_](?=\S)[^*_\n]+(?<=\S)[*_](?!\w)',
);
final _inlineCodePattern = RegExp(r'(?<!\\)(`+)([^`\n]+?)\1');

/// The current document of `controller` as a Quill [Delta].
Delta deltaFromController(QuillController controller) {
  return controller.document.toDelta();
}

/// Serializes a Quill [Delta] to its JSON string form (the format persisted in
/// `EntryText.quill`).
String quillJsonFromDelta(Delta delta) {
  return jsonEncode(delta.toJson());
}

/// Snapshots a Quill `controller` into an [EntryText] holding all three
/// representations the app stores: plain text, markdown, and the Quill JSON
/// delta. This is the canonical editor → persistence conversion.
EntryText entryTextFromController(QuillController controller) {
  final delta = deltaFromController(controller);
  final json = quillJsonFromDelta(delta);
  final markdown = deltaToMarkdown(json);

  return EntryText(
    plainText: controller.document.toPlainText(),
    markdown: markdown,
    quill: json,
  );
}

/// Builds a [QuillController] from a serialized Quill JSON document, restoring
/// `selection` when given. Returns a blank controller for null or empty
/// (`'[]'`) input. Shared by the live editor and the read-only text viewers.
QuillController makeController({
  String? serializedQuill,
  TextSelection? selection,
  bool markdownPasteEnabled = false,
}) {
  late final QuillController controller;
  final config = markdownPasteEnabled
      ? QuillControllerConfig(
          clipboardConfig: QuillClipboardConfig(
            // Keep Flutter Quill's HTML/explicit-Markdown conversion ahead of
            // the plain-text callback. The callback only runs after those
            // richer clipboard formats were unavailable.
            enableExternalRichPaste: true,
            onPlainTextPaste: (plainText) async =>
                handlePlainTextMarkdownPaste(controller, plainText),
          ),
        )
      : const QuillControllerConfig();

  if (serializedQuill != null && serializedQuill != '[]') {
    final editorJson = json.decode(serializedQuill) as List<dynamic>;
    controller = QuillController(
      document: Document.fromJson(editorJson),
      selection: selection ?? const TextSelection.collapsed(offset: 0),
      config: config,
    );
  } else {
    controller = QuillController.basic(config: config);
  }
  return controller;
}

/// Whether [text] contains Markdown syntax that should become rich text.
///
/// Detection is deliberately syntax-based: ordinary prose, hashtags such as
/// `#topic`, arithmetic using `*`, and emoji continue through Quill's normal
/// plain-text paste path unchanged.
bool containsMarkdownFormatting(String text) =>
    _markdownBlockPattern.hasMatch(text) ||
    _markdownHorizontalRulePattern.hasMatch(text) ||
    _markdownInlinePattern.hasMatch(text) ||
    _markdownItalicPattern.hasMatch(text) ||
    _inlineCodePattern.hasMatch(text);

/// Converts Markdown-looking clipboard text into a Quill [Delta].
///
/// Lotti's canonical `delta_markdown` converter supplies block and inline
/// formatting plus the custom horizontal-rule embed. Its decoder predates
/// Flutter Quill's inline-code support, so code spans are protected while it
/// parses and restored with Quill's `code` attribute afterward.
Delta? markdownDeltaForPaste(String text) {
  if (!containsMarkdownFormatting(text)) return null;

  final protected = _protectInlineCode(text);
  final encoded = markdownToDelta(protected.markdown);
  final decoded = jsonDecode(encoded) as List<dynamic>;
  final delta = Delta.fromJson(decoded);
  return _restoreInlineCode(delta, protected.inlineCodeByToken);
}

/// Inserts Markdown-looking [plainText] at the current selection.
///
/// Returns an empty string after handling the paste so Flutter Quill's
/// subsequent plain-text insertion is a no-op. Returns `null` for genuine
/// plain text, which tells Quill to use its unchanged default behavior.
String? handlePlainTextMarkdownPaste(
  QuillController controller,
  String plainText,
) {
  final delta = markdownDeltaForPaste(plainText);
  if (delta == null) return null;

  final selection = controller.selection;
  final start = math.min(selection.baseOffset, selection.extentOffset);
  final length = (selection.baseOffset - selection.extentOffset).abs();
  final insertedLength = delta.toList().fold<int>(
    0,
    (sum, operation) => sum + (operation.length ?? 0),
  );
  controller
    ..replaceText(
      start,
      length,
      delta,
      null,
    )
    ..moveCursorToPosition(start + insertedLength);
  return '';
}

({String markdown, Map<String, String> inlineCodeByToken}) _protectInlineCode(
  String markdown,
) {
  final inlineCodeByToken = <String, String>{};
  final protected = markdown.replaceAllMapped(_inlineCodePattern, (match) {
    final code = match.group(2)!;
    final index = inlineCodeByToken.length;
    var discriminator = 0;
    late String token;
    do {
      final suffix = discriminator == 0 ? '' : '-$discriminator';
      token = '\u{E000}lotti-inline-code-$index$suffix\u{E001}';
      discriminator++;
    } while (markdown.contains(token));
    inlineCodeByToken[token] = _normalizeInlineCode(code);
    return token;
  });
  return (markdown: protected, inlineCodeByToken: inlineCodeByToken);
}

String _normalizeInlineCode(String code) {
  final normalizedWhitespace = code.replaceAll(RegExp(r'\s+'), ' ');
  if (normalizedWhitespace.length > 2 &&
      normalizedWhitespace.startsWith(' ') &&
      normalizedWhitespace.endsWith(' ') &&
      normalizedWhitespace.trim().isNotEmpty) {
    return normalizedWhitespace.substring(1, normalizedWhitespace.length - 1);
  }
  return normalizedWhitespace;
}

Delta _restoreInlineCode(Delta delta, Map<String, String> inlineCodeByToken) {
  if (inlineCodeByToken.isEmpty) return delta;

  final restored = Delta();
  final tokenPattern = RegExp(
    inlineCodeByToken.keys.map(RegExp.escape).join('|'),
  );
  for (final operation in delta.toList()) {
    final value = operation.value;
    final attributes = operation.attributes;
    if (value is! String) {
      restored.insert(value, attributes);
      continue;
    }

    var cursor = 0;
    for (final match in tokenPattern.allMatches(value)) {
      if (match.start > cursor) {
        restored.insert(value.substring(cursor, match.start), attributes);
      }
      restored.insert(
        inlineCodeByToken[match.group(0)],
        <String, dynamic>{...?attributes, Attribute.inlineCode.key: true},
      );
      cursor = match.end;
    }
    if (cursor < value.length) {
      restored.insert(value.substring(cursor), attributes);
    }
  }
  return restored;
}

/// Inserts a Quill `divider` embed at the current selection.
///
/// The function preserves editor focus by toggling [QuillController.skipRequestKeyboard]
/// during the mutation, replaces any currently selected text with the divider,
/// and moves the caret directly after the inserted embed so users can continue typing.
void insertDividerEmbed(QuillController controller) {
  final selection = controller.selection;
  final index = math.min(selection.baseOffset, selection.extentOffset);
  final length = (selection.baseOffset - selection.extentOffset).abs();

  controller
    ..skipRequestKeyboard = true
    ..replaceText(
      index,
      length,
      const BlockEmbed('divider', 'hr'),
      null,
    )
    ..moveCursorToPosition(index + 1)
    ..skipRequestKeyboard = false;
}
