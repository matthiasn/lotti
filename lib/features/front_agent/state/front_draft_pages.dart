import 'package:flutter/foundation.dart';

/// One page of the companion's chat box: words, and — when they were taken
/// back from a stopped turn — that turn, which they replace once sent.
@immutable
class FrontDraftPage {
  const FrontDraftPage(this.text, {this.editingMessageId});

  final String text;
  final String? editingMessageId;

  bool get isBlank => text.trim().isEmpty;

  @override
  bool operator ==(Object other) =>
      other is FrontDraftPage &&
      other.text == text &&
      other.editingMessageId == editingMessageId;

  @override
  int get hashCode => Object.hash(text, editingMessageId);
}

/// The chat box's pages: what the user was typing is never thrown away when
/// the words of a stopped turn are taken back into the box — each is a page,
/// and the user flips between them. [index] is the page in the box.
///
/// Blank pages do not linger: one left blank is dropped as soon as another
/// is shown, so the pager counts only pages with words on them.
@immutable
class FrontDraftPages {
  FrontDraftPages(List<FrontDraftPage> pages, this.index)
    : pages = List.unmodifiable(pages),
      assert(pages.isNotEmpty, 'the box always has a page'),
      assert(index >= 0 && index < pages.length, 'index out of range');

  /// The box as it is, out of the page in it and those [aside], the one in
  /// it being at [index].
  factory FrontDraftPages.of({
    required FrontDraftPage current,
    required List<FrontDraftPage> aside,
    required int index,
  }) => FrontDraftPages([
    ...aside.take(index),
    current,
    ...aside.skip(index),
  ], index);

  /// Whatever [pages] are left after a send, with words on them: the last
  /// in the box, or an empty box when none has.
  factory FrontDraftPages.settle(List<FrontDraftPage> pages) {
    final kept = [
      for (final page in pages)
        if (!page.isBlank) page,
    ];
    return kept.isEmpty
        ? FrontDraftPages(const [FrontDraftPage('')], 0)
        : FrontDraftPages(kept, kept.length - 1);
  }

  final List<FrontDraftPage> pages;
  final int index;

  FrontDraftPage get current => pages[index];

  /// Every page but the one in the box, in order.
  List<FrontDraftPage> get aside => [...pages]..removeAt(index);

  /// Page [target] in the box, any other left blank dropped.
  FrontDraftPages showing(int target) {
    if (target < 0 || target >= pages.length) return this;
    final kept = [
      for (var i = 0; i < pages.length; i++)
        if (i == target || !pages[i].isBlank) i,
    ];
    return FrontDraftPages([
      for (final i in kept) pages[i],
    ], kept.indexOf(target));
  }

  /// [page] in the box, after the others. The words of a turn already on a
  /// page are shown where they are, not paged twice; a blank box simply
  /// takes them.
  FrontDraftPages adding(FrontDraftPage page) {
    final existing = pages.indexWhere(
      (p) =>
          page.editingMessageId != null &&
          p.editingMessageId == page.editingMessageId,
    );
    if (existing >= 0) return showing(existing);
    // A blank box — the page in it, or any other — keeps no page of its own.
    final kept = [...pages.where((p) => !p.isBlank), page];
    return FrontDraftPages(kept, kept.length - 1);
  }
}
